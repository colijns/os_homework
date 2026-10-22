#include <assert.h>
#include <list.h>
#include <pmm.h>
#include <slub.h>
#include <string.h>

/* Lab2 C. Adapted to this kernel's Page/VA conventions, not copied from Linux.
 * References and simplifications are documented in report/slub_report.md.
 * Metadata lives inside allocated pages; struct Page and all PMMs stay intact.
 */
#define SLUB_SMALL_MAGIC 0x534c5542534d414cULL
#define SLUB_LARGE_MAGIC 0x534c55424c415247ULL
#define SLUB_CACHE_COUNT 8
#define SLUB_BITMAP_WORDS (PGSIZE / SLUB_ALIGNMENT / 64)

struct slub_cache {
    size_t object_size;
    list_entry_t partial;
};

struct slub_slab {
    uint64_t magic;
    struct slub_cache *cache;
    list_entry_t link;
    void *freelist;
    size_t inuse;
    size_t capacity;
    uint64_t allocated[SLUB_BITMAP_WORDS];
};

struct slub_large {
    uint64_t magic;
    size_t npages;
};

#define SLUB_OBJECT_OFFSET ROUNDUP(sizeof(struct slub_slab), SLUB_ALIGNMENT)
#define SLUB_LARGE_OFFSET ROUNDUP(sizeof(struct slub_large), SLUB_ALIGNMENT)

static struct slub_cache caches[SLUB_CACHE_COUNT];
static bool slub_ready;

static void *page_address(struct Page *page) {
    /* KADDR is disabled in the supplied pmm.h. Use its existing direct map. */
    return (void *)(page2pa(page) + va_pa_offset);
}

static struct Page *address_page(const void *address) {
    return pa2page(PADDR(address));
}

static bool known_cache(const struct slub_cache *cache) {
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i ++) {
        if (cache == &caches[i]) {
            return 1;
        }
    }
    return 0;
}

static size_t object_index(const struct slub_slab *slab, const void *object) {
    uintptr_t first = (uintptr_t)slab + SLUB_OBJECT_OFFSET;
    uintptr_t address = (uintptr_t)object;
    assert(known_cache(slab->cache));
    assert(address >= first);
    size_t offset = address - first;
    assert(offset % slab->cache->object_size == 0);
    size_t index = offset / slab->cache->object_size;
    assert(index < slab->capacity);
    return index;
}

static struct slub_slab *new_slab(struct slub_cache *cache) {
    struct Page *page = alloc_page();
    if (page == NULL) {
        return NULL;
    }
    struct slub_slab *slab = page_address(page);
    memset(slab, 0, sizeof(*slab));
    slab->magic = SLUB_SMALL_MAGIC;
    slab->cache = cache;
    slab->capacity = (PGSIZE - SLUB_OBJECT_OFFSET) / cache->object_size;
    assert(slab->capacity > 0);
    assert(slab->capacity <= SLUB_BITMAP_WORDS * 64);

    /* The next-free pointer occupies the first word of a FREE object only. */
    for (size_t i = slab->capacity; i > 0; i --) {
        void *object = (char *)slab + SLUB_OBJECT_OFFSET
                       + (i - 1) * cache->object_size;
        *(void **)object = slab->freelist;
        slab->freelist = object;
    }
    list_add(&cache->partial, &slab->link);
    return slab;
}

void slub_init(void) {
    assert(!slub_ready);
    assert(pmm_manager != NULL && pages != NULL);
    for (size_t i = 0, size = SLUB_ALIGNMENT; i < SLUB_CACHE_COUNT;
         i ++, size <<= 1) {
        caches[i].object_size = size;
        list_init(&caches[i].partial);
    }
    slub_ready = 1;
}

static void *alloc_large(size_t size) {
    if (size > (size_t)-1 - SLUB_LARGE_OFFSET) {
        return NULL;
    }
    size_t total = size + SLUB_LARGE_OFFSET;
    size_t needed = total / PGSIZE + (total % PGSIZE != 0);
    size_t managed_pages = npage - nbase;
    if (needed > managed_pages) {
        return NULL;
    }
    /* Buddy rounds n up. Request/store the same power of two for every PMM,
     * so free_pages never receives a different size or a partial Buddy block.
     */
    size_t npages = 1;
    while (npages < needed) {
        if (npages > managed_pages / 2) {
            return NULL;
        }
        npages <<= 1;
    }
    struct Page *page = alloc_pages(npages);
    if (page == NULL) {
        return NULL;
    }
    struct slub_large *large = page_address(page);
    large->magic = SLUB_LARGE_MAGIC;
    large->npages = npages;
    return (char *)large + SLUB_LARGE_OFFSET;
}

void *kmalloc(size_t size) {
    assert(slub_ready);
    if (size == 0) {
        return NULL;
    }
    if (size > SLUB_MAX_SMALL_SIZE) {
        return alloc_large(size);
    }
    struct slub_cache *cache = &caches[0];
    while (cache->object_size < size) {
        cache ++;
    }
    struct slub_slab *slab;
    if (list_empty(&cache->partial)) {
        slab = new_slab(cache);
        if (slab == NULL) {
            return NULL;
        }
    } else {
        slab = to_struct(list_next(&cache->partial), struct slub_slab, link);
    }
    assert(slab->magic == SLUB_SMALL_MAGIC && slab->inuse < slab->capacity);
    void *object = slab->freelist;
    assert(object != NULL);
    size_t index = object_index(slab, object);
    uint64_t mask = 1ULL << (index % 64);
    assert((slab->allocated[index / 64] & mask) == 0);
    slab->freelist = *(void **)object;
    slab->allocated[index / 64] |= mask;
    slab->inuse ++;
    if (slab->inuse == slab->capacity) {
        assert(slab->freelist == NULL);
        list_del_init(&slab->link);
    }
    return object;
}

void kfree(void *ptr) {
    if (ptr == NULL) {
        return;
    }
    assert(slub_ready);
    uintptr_t base = ROUNDDOWN((uintptr_t)ptr, PGSIZE);
    assert(base >= KERNBASE && PADDR(base) < npage * PGSIZE);
    uint64_t magic = *(uint64_t *)base;
    if (magic == SLUB_LARGE_MAGIC) {
        struct slub_large *large = (struct slub_large *)base;
        assert((uintptr_t)ptr == base + SLUB_LARGE_OFFSET);
        size_t npages = large->npages;
        assert(npages > 0 && (npages & (npages - 1)) == 0);
        assert(npages <= npage - PPN(PADDR(base)));
        large->magic = 0;
        free_pages(address_page(large), npages);
        return;
    }
    assert(magic == SLUB_SMALL_MAGIC);
    struct slub_slab *slab = (struct slub_slab *)base;
    size_t index = object_index(slab, ptr);
    uint64_t mask = 1ULL << (index % 64);
    assert((slab->allocated[index / 64] & mask) != 0);
    assert(slab->inuse > 0 && slab->inuse <= slab->capacity);
    if (slab->inuse == slab->capacity) {
        /* The first free object makes a previously full slab partial. */
        list_add(&slab->cache->partial, &slab->link);
    }
    slab->allocated[index / 64] &= ~mask;
    *(void **)ptr = slab->freelist;
    slab->freelist = ptr;
    slab->inuse --;
    if (slab->inuse == 0) {
        /* Release empty slabs immediately: tests can prove full page recovery. */
        list_del_init(&slab->link);
        slab->magic = 0;
        free_page(address_page(slab));
    }
}
