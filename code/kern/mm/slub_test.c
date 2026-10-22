#include <assert.h>
#include <pmm.h>
#include <slub.h>
#include <stdio.h>
#include <string.h>

/* Independent black-box checks: only the public SLUB/PMM interfaces are used.
 * No access to cache arrays, slab headers, bitmaps or allocator-private helpers.
 */
static void *many[300];

static void *page_address(struct Page *page) {
    return (void *)(page2pa(page) + va_pa_offset);
}

static uint8_t pattern(size_t offset, unsigned seed) {
    return (uint8_t)(seed + offset * 17 + (offset >> 8));
}

static void write_pattern(void *ptr, size_t size, unsigned seed) {
    assert(ptr != NULL && ((uintptr_t)ptr % SLUB_ALIGNMENT) == 0);
    for (size_t i = 0; i < size; i ++) {
        ((uint8_t *)ptr)[i] = pattern(i, seed);
    }
}

static void check_pattern(const void *ptr, size_t size, unsigned seed) {
    for (size_t i = 0; i < size; i ++) {
        assert(((const uint8_t *)ptr)[i] == pattern(i, seed));
    }
}

static void check_boundaries(void) {
    static const size_t sizes[] = {
        1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
        255, 256, 257, 511, 512, 513, 1023, 1024, 1025, 2047,
        2048, 2049, 4095, 4096, 4097, 8192, 8193, 16384
    };
    void *objects[sizeof(sizes) / sizeof(sizes[0])];
    size_t before = nr_free_pages();
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i ++) {
        objects[i] = kmalloc(sizes[i]);
        write_pattern(objects[i], sizes[i], (unsigned)i);
        for (size_t j = 0; j < i; j ++) {
            uintptr_t a = (uintptr_t)objects[i], b = (uintptr_t)objects[j];
            assert(a + sizes[i] <= b || b + sizes[j] <= a);
        }
    }
    for (size_t i = sizeof(sizes) / sizeof(sizes[0]); i > 0; i --) {
        check_pattern(objects[i - 1], sizes[i - 1], (unsigned)(i - 1));
        kfree(objects[i - 1]);
    }
    assert(nr_free_pages() == before);
    cprintf("[SLUB 1/8] sizes, alignment, isolation and payload: PASS\n");
}

static void check_page_sharing(void) {
    size_t before = nr_free_pages();
    for (size_t i = 0; i < 32; i ++) {
        many[i] = kmalloc(64);
        write_pattern(many[i], 64, (unsigned)i);
    }
    /* 32 small objects must share a page instead of costing 32 physical pages. */
    assert(before - nr_free_pages() == 1);
    for (size_t i = 0; i < 32; i ++) {
        check_pattern(many[i], 64, (unsigned)i);
        kfree(many[i]);
    }
    assert(nr_free_pages() == before);
    cprintf("[SLUB 2/8] 32 small objects share one page: PASS\n");
}

static void check_full_to_partial(void) {
    size_t before = nr_free_pages();
    for (size_t i = 0; i < 300; i ++) {
        many[i] = kmalloc(16);
        write_pattern(many[i], 16, (unsigned)i);
    }
    assert(nr_free_pages() < before - 1);
    void *released = many[10];
    /* The first page must be full before this free; it must become usable. */
    assert(ROUNDDOWN((uintptr_t)many[0], PGSIZE)
           != ROUNDDOWN((uintptr_t)many[299], PGSIZE));
    kfree(released);
    many[10] = kmalloc(16);
    assert(many[10] == released);
    write_pattern(many[10], 16, 10);
    /* Non-LIFO freeing exercises freelist updates without damaging live data. */
    for (size_t parity = 0; parity < 2; parity ++) {
        for (size_t i = parity; i < 300; i += 2) {
            check_pattern(many[i], 16, (unsigned)i);
            kfree(many[i]);
        }
    }
    assert(nr_free_pages() == before);
    cprintf("[SLUB 3/8] slab growth, full-to-partial and slot reuse: PASS\n");
}

static void check_large_recovery(void) {
    size_t before = nr_free_pages();
    /* Fixed expected results include the specified 16-byte large-object header.
     * These pairs straddle the REAL rounding boundary, not only payload pages.
     */
    static const struct { size_t size, pages; } edges[] = {
        {4080, 1}, {4081, 2}, {8176, 2}, {8177, 4},
        {16368, 4}, {16369, 8}
    };
    for (size_t i = 0; i < sizeof(edges) / sizeof(edges[0]); i ++) {
        void *ptr = kmalloc(edges[i].size);
        write_pattern(ptr, edges[i].size, (unsigned)i);
        assert(before - nr_free_pages() == edges[i].pages);
        check_pattern(ptr, edges[i].size, (unsigned)i);
        kfree(ptr);
        assert(nr_free_pages() == before);
    }
    for (size_t round = 0; round < 12; round ++) {
        void *a = kmalloc(8192), *b = kmalloc(16384);
        write_pattern(a, 8192, 21);
        write_pattern(b, 16384, 42);
        /* Header + payload cross page boundaries; Buddy must recover all pages. */
        check_pattern(a, 8192, 21);
        check_pattern(b, 16384, 42);
        kfree(a);
        kfree(b);
        assert(nr_free_pages() == before);
    }
    cprintf("[SLUB 4/8] multi-page objects and exact page recovery: PASS\n");
}

static void check_invalid_sizes(void) {
    size_t before = nr_free_pages();
    assert(kmalloc(0) == NULL);
    assert(kmalloc((size_t)-1) == NULL);
    assert(kmalloc((size_t)-16) == NULL);
    assert(kmalloc((npage - nbase) * PGSIZE) == NULL);
    kfree(NULL);
    assert(nr_free_pages() == before);
    cprintf("[SLUB 5/8] zero, overflow, oversize and NULL free: PASS\n");
}

static void check_mixed_lifetimes(void) {
    static const size_t sizes[] = {1, 16, 23, 65, 127, 257, 511, 1025, 2048, 2049, 4096, 8193};
    struct live_object { void *ptr; size_t size; unsigned seed; } live[48];
    memset(live, 0, sizeof(live));
    size_t before = nr_free_pages();
    uint32_t state = 0x24120003;
    for (unsigned step = 0; step < 2000; step ++) {
        state = state * 1664525U + 1013904223U;
        size_t index = (state >> 16) % 48;
        if (live[index].ptr != NULL) {
            check_pattern(live[index].ptr, live[index].size, live[index].seed);
            kfree(live[index].ptr);
            live[index].ptr = NULL;
        } else {
            size_t size = sizes[(state >> 8) % (sizeof(sizes) / sizeof(sizes[0]))];
            void *ptr = kmalloc(size);
            write_pattern(ptr, size, step);
            for (size_t j = 0; j < 48; j ++) {
                if (live[j].ptr != NULL) {
                    uintptr_t a = (uintptr_t)ptr, b = (uintptr_t)live[j].ptr;
                    assert(a + size <= b || b + live[j].size <= a);
                }
            }
            live[index].ptr = ptr;
            live[index].size = size;
            live[index].seed = step;
        }
    }
    for (size_t i = 0; i < 48; i ++) {
        if (live[i].ptr != NULL) {
            check_pattern(live[i].ptr, live[i].size, live[i].seed);
            kfree(live[i].ptr);
        }
    }
    assert(nr_free_pages() == before);
    cprintf("[SLUB 6/8] 2000 mixed-lifetime operations: PASS\n");
}

static void check_exhaustion(void) {
    size_t before = nr_free_pages();
    void *keeper = kmalloc(64);
    write_pattern(keeper, 64, 93);
    struct Page *held = NULL, *page;
    size_t count = 0;
    /* Hold every remaining page. Store next pointers in the held page itself,
     * without changing Page metadata or substituting a fake PMM.
     */
    while ((page = alloc_page()) != NULL) {
        *(struct Page **)page_address(page) = held;
        held = page;
        count ++;
    }
    assert(nr_free_pages() == 0);
    assert(kmalloc(2048) == NULL);    // a new slab requires a page
    assert(kmalloc(8192) == NULL);    // a large object requires pages
    assert(nr_free_pages() == 0);
    void *cached = kmalloc(64);      // an existing partial slab still works
    write_pattern(cached, 64, 71);
    check_pattern(keeper, 64, 93);
    kfree(cached);
    while (held != NULL) {
        page = held;
        held = *(struct Page **)page_address(page);
        free_page(page);
    }
    check_pattern(keeper, 64, 93);
    kfree(keeper);
    assert(nr_free_pages() == before);
    cprintf("[SLUB 7/8] real OOM, cached allocation and recovery (%u held pages): PASS\n",
            (unsigned)count);
}

void slub_check(void) {
    size_t before = nr_free_pages();
    cprintf("slub_check begin: manager=%s free_pages=%u\n",
            pmm_manager->name, (unsigned)before);
    check_boundaries();
    check_page_sharing();
    check_full_to_partial();
    check_large_recovery();
    check_invalid_sizes();
    check_mixed_lifetimes();
    check_exhaustion();
    /* Re-run the existing PMM's OWN checks after SLUB has used and freed pages. */
    pmm_manager->check();
    assert(nr_free_pages() == before);
    cprintf("[SLUB 8/8] underlying PMM recheck and page balance: PASS\n");
    cprintf("slub_check succeeded! 8/8 groups; free_pages=%u -> %u\n",
            (unsigned)before, (unsigned)nr_free_pages());
}
