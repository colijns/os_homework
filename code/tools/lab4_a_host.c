/* Host-only test harness. Subject definitions/functions are extracted at run time. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#undef assert
#define assert(condition) do { if (!(condition)) { \
    fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #condition); \
    exit(EXIT_FAILURE); \
} } while (0)
typedef uintptr_t uint_t;
typedef size_t ppn_t;
#define E_NO_MEM 4
#define panic(...) abort()
#define to_struct(ptr, type, member) ((type *)((char *)(ptr) - offsetof(type, member)))
#include "a_types.h"

enum { POOL_PAGES = 32 };
static struct Page page_pool[POOL_PAGES];
static unsigned char physical_memory[POOL_PAGES][PGSIZE];
static bool allocated[POOL_PAGES];
struct Page *pages = page_pool;
size_t npage = 0x80000 + POOL_PAGES;
const size_t nbase = 0x80000;
uintptr_t boot_pgdir_pa = 0x81234000;
static pde_t root[NPDEENTRY];
static int free_count, free_calls, alloc_calls, alloc_budget, tlb_calls;
static pde_t *last_tlb_root;
static uintptr_t last_tlb_address;
static bool fail_kmalloc;
static struct proc_struct pcb_storage;

#define KADDR(pa) ((void *)((unsigned char *)physical_memory + ((pa) - (nbase << PGSHIFT))))
#include "a_helpers.h"

static struct Page *alloc_page(void)
{
    alloc_calls++;
    if (alloc_budget == 0) return NULL;
    if (alloc_budget > 0) alloc_budget--;
    for (int i = 0; i < POOL_PAGES; i++)
    {
        if (!allocated[i])
        {
            allocated[i] = true;
            free_count--;
            memset(&pages[i], 0, sizeof(pages[i]));
            memset(physical_memory[i], 0xA5, PGSIZE);
            return &pages[i];
        }
    }
    return NULL;
}

static void free_page(struct Page *page)
{
    ptrdiff_t index = page - pages;
    assert(index >= 0 && index < POOL_PAGES);
    assert(allocated[index] && page_ref(page) == 0);
    allocated[index] = false;
    free_count++;
    free_calls++;
}

static void tlb_invalidate(pde_t *pgdir, uintptr_t la)
{
    tlb_calls++;
    last_tlb_root = pgdir;
    last_tlb_address = la;
}

static void *kmalloc(size_t size)
{
    assert(size == sizeof(pcb_storage));
    return fail_kmalloc ? NULL : &pcb_storage;
}

#include "a_functions.h"

/* Compile the existing allocator too: a page returned by A must be reusable. */
static free_area_t free_area;
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)
#define PG_reserved 0
#define PG_property 1
#define PageReserved(p) (((p)->flags >> PG_reserved) & 1U)
#define PageProperty(p) (((p)->flags >> PG_property) & 1U)
#define SetPageProperty(p) ((p)->flags |= 1U << PG_property)
#define ClearPageProperty(p) ((p)->flags &= ~(1U << PG_property))
#define le2page(le, member) to_struct(le, struct Page, member)
#include "a_bestfit.h"
#undef free_list
#undef nr_free

static void reset(void)
{
    memset(page_pool, 0, sizeof(page_pool));
    memset(allocated, 0, sizeof(allocated));
    memset(root, 0, sizeof(root));
    free_count = POOL_PAGES;
    free_calls = alloc_calls = tlb_calls = 0;
    alloc_budget = -1;
    last_tlb_root = NULL;
    last_tlb_address = 0;
    fail_kmalloc = false;
    memset(&pcb_storage, 0xA5, sizeof(pcb_storage));
}

static void insert_permissions(void)
{
    struct Page *p = alloc_page();
    uintptr_t la = 0x123;
    unsigned perm = PTE_U | PTE_R | PTE_W;
    assert(page_insert(root, p, la, perm) == 0);
    pte_t *entry = get_pte(root, la, false);
    assert(entry != NULL && pte2page(*entry) == p && page_ref(p) == 1);
    assert((*entry & 0x3FF) == (perm | PTE_V));
    assert(tlb_calls == 1 && last_tlb_root == root && last_tlb_address == la);
    assert(get_pte(root, 0, false) == entry);
}

static void same_page_permissions(void)
{
    struct Page *p = alloc_page();
    assert(page_insert(root, p, 0, PTE_W | PTE_U) == 0);
    int before = free_count;
    assert(page_insert(root, p, 0, PTE_R) == 0);
    assert(page_ref(p) == 1 && free_count == before && free_calls == 0);
    assert((*get_pte(root, 0, false) & 0x3FF) == (PTE_V | PTE_R));
    assert(tlb_calls == 2);
}

static void aliases_and_replacement(void)
{
    struct Page *p = alloc_page(), *q = alloc_page();
    assert(page_insert(root, p, 0, 0) == 0);
    assert(page_insert(root, p, PGSIZE, 0) == 0);
    assert(page_ref(p) == 2);
    assert(page_insert(root, q, PGSIZE, PTE_R) == 0);
    assert(page_ref(p) == 1 && page_ref(q) == 1 && free_calls == 0);
    page_remove(root, 0);
    assert(page_ref(p) == 0 && free_calls == 1);
    assert(pte2page(*get_pte(root, PGSIZE, false)) == q);
    page_remove(root, PGSIZE);
    assert(page_ref(q) == 0 && free_calls == 2);
}

static void replace_last_reference(void)
{
    struct Page *p = alloc_page(), *q = alloc_page();
    assert(page_insert(root, p, 0, PTE_R) == 0);
    assert(page_insert(root, q, 0, PTE_R | PTE_W) == 0);
    assert(page_ref(p) == 0 && !allocated[p - pages]);
    assert(page_ref(q) == 1 && allocated[q - pages] && free_calls == 1);
    assert(pte2page(*get_pte(root, 0, false)) == q);
}

static void remove_missing(void)
{
    page_remove(root, 3 * PGSIZE);
    assert(alloc_calls == 0 && free_calls == 0 && tlb_calls == 0);
    assert(free_count == POOL_PAGES && root[0] == 0);
}

static void remove_twice(void)
{
    struct Page *p = alloc_page();
    assert(page_insert(root, p, 0, PTE_R) == 0);
    page_remove(root, 0);
    int before_free = free_calls, before_tlb = tlb_calls, before_alloc = alloc_calls;
    assert(*get_pte(root, 0, false) == 0 && page_ref(p) == 0);
    page_remove(root, 0);
    assert(free_calls == before_free && tlb_calls == before_tlb && alloc_calls == before_alloc);
}

static void multilevel_indices(void)
{
    struct Page *p = alloc_page(), *q = alloc_page();
    uintptr_t second = ((uintptr_t)1 << PDX1SHIFT) | ((uintptr_t)3 << PDX0SHIFT) | (7 * PGSIZE);
    assert(page_insert(root, p, 0, PTE_R) == 0);
    assert(page_insert(root, q, second, PTE_R) == 0);
    assert(root[0] != 0 && root[1] != 0);
    assert(pte2page(*get_pte(root, 0, false)) == p);
    assert(pte2page(*get_pte(root, second + 123, false)) == q);
    assert(get_pte(root, second, false) != get_pte(root, 0, false));
}

static void failure_first_table(void)
{
    struct Page *p = alloc_page();
    int before = free_count;
    alloc_budget = 0;
    assert(page_insert(root, p, 0, PTE_R) == -E_NO_MEM);
    assert(root[0] == 0 && page_ref(p) == 0 && free_count == before && tlb_calls == 0);
}

static void failure_second_table_and_retry(void)
{
    struct Page *p = alloc_page();
    int before = free_count;
    alloc_budget = 1;
    assert(page_insert(root, p, 0, PTE_R) == -E_NO_MEM);
    assert(root[0] == 0 && page_ref(p) == 0 && free_count == before);
    alloc_budget = -1;
    assert(page_insert(root, p, 0, PTE_R) == 0);
    assert(page_ref(p) == 1 && free_count == before - 2);
}

static void failure_preserves_existing_table(void)
{
    struct Page *p = alloc_page(), *q = alloc_page();
    assert(page_insert(root, p, 0, PTE_R) == 0);
    pde_t before_root = root[0];
    int before = free_count;
    alloc_budget = 0;
    assert(page_insert(root, q, (uintptr_t)1 << PDX0SHIFT, PTE_R) == -E_NO_MEM);
    assert(root[0] == before_root && free_count == before && page_ref(q) == 0);
    assert(pte2page(*get_pte(root, 0, false)) == p && page_ref(p) == 1);
    assert(get_pte(root, (uintptr_t)1 << PDX0SHIFT, false) == NULL);
}

static void pcb_initial_state(void)
{
    struct proc_struct *p = alloc_proc();
    struct context zero = {0};
    assert(p == &pcb_storage && p->state == PROC_UNINIT && p->pid == -1);
    assert(p->runs == 0 && p->kstack == 0 && !p->need_resched);
    assert(p->parent == NULL && p->mm == NULL && p->tf == NULL && p->flags == 0);
    assert(memcmp(&p->context, &zero, sizeof(zero)) == 0 && p->pgdir == boot_pgdir_pa);
    for (size_t i = 0; i < sizeof(p->name); i++) assert(p->name[i] == '\0');
    assert(p->list_link.next == &p->list_link && p->list_link.prev == &p->list_link);
    assert(p->hash_link.next == &p->hash_link && p->hash_link.prev == &p->hash_link);
}

static void pcb_allocation_failure(void)
{
    fail_kmalloc = true;
    assert(alloc_proc() == NULL);
    for (size_t i = 0; i < sizeof(pcb_storage); i++) assert(((unsigned char *)&pcb_storage)[i] == 0xA5);
}

static void bestfit_tail_insert(void)
{
    best_fit_init();
    for (int i = 0; i < POOL_PAGES; i++) pages[i].flags = 1U << PG_reserved;
    best_fit_init_memmap(pages, 2);
    best_fit_init_memmap(pages + 6, 2);
    assert(best_fit_nr_free_pages() == 4);
    assert((pages + 6)->page_link.prev == &pages->page_link);
    struct Page *a = best_fit_alloc_pages(2), *b = best_fit_alloc_pages(2);
    assert(a == pages && b == pages + 6 && best_fit_nr_free_pages() == 0);
    best_fit_free_pages(a, 2);
    best_fit_free_pages(b, 2);
    assert(best_fit_nr_free_pages() == 4);
    assert(free_area.free_list.next == &a->page_link);
    assert(a->page_link.next == &b->page_link && b->page_link.next == &free_area.free_list);
    assert(b->page_link.prev == &a->page_link && a->page_link.prev == &free_area.free_list);
}

static void bestfit_coalesce_after_tail_free(void)
{
    best_fit_init();
    for (int i = 0; i < POOL_PAGES; i++) pages[i].flags = 1U << PG_reserved;
    best_fit_init_memmap(pages, 4);
    struct Page *a = best_fit_alloc_pages(2), *b = best_fit_alloc_pages(2);
    assert(a == pages && b == pages + 2);
    best_fit_free_pages(a, 2);
    best_fit_free_pages(b, 2);
    assert(a->property == 4 && best_fit_nr_free_pages() == 4);
    assert(best_fit_alloc_pages(4) == pages);
}

static void run(const char *name, void (*test)(void))
{
    reset();
    printf("[RUN] %s\n", name);
    fflush(stdout);
    test();
    printf("[PASS] %s\n", name);
}

int main(void)
{
    run("insert and permissions", insert_permissions);
    run("same-page permission update", same_page_permissions);
    run("aliases and replacement", aliases_and_replacement);
    run("replace the last reference", replace_last_reference);
    run("remove an absent mapping", remove_missing);
    run("remove twice", remove_twice);
    run("Sv39 table indices in the memory model", multilevel_indices);
    run("first table allocation failure", failure_first_table);
    run("second table allocation rollback and retry", failure_second_table_and_retry);
    run("allocation failure preserves existing mappings", failure_preserves_existing_table);
    run("PCB initialization over dirty memory", pcb_initial_state);
    run("PCB allocation failure", pcb_allocation_failure);
    run("existing best-fit tail insertion", bestfit_tail_insert);
    run("existing best-fit coalescing after tail free", bestfit_coalesce_after_tail_free);
    puts("14/14 host checks passed.");
    return 0;
}
