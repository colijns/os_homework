#include <pmm.h>
#include <list.h>
#include <string.h>
#include <buddy_fit_pmm.h>
#include <stdio.h>

/*
 * Buddy System 物理页分配算法
 *
 * 数据组织：按阶分级的空闲块链表 free_area[order]，
 * 第 order 级链表中的每个空闲块大小恒为 2^order 页，
 * 块头页 SetPageProperty 且 property = 2^order（块内其余页 flags 为 0）。
 * 伙伴定位：物理页号 pfn 的 order 级伙伴 = pfn ^ (1 << order)。
 *
 * 接口语义（与 default_pmm 对齐）：
 *   alloc_pages(n)：实际分配 2^k 页（k 为使 2^k >= n 的最小整数）；
 *   free_pages(base, n)：按同样的向上取整 2^k 归还整块。
 *   nr_free 按"块入链/出链"维护，页数守恒，与 alloc 对称。
 */

// 最大阶数：2^19 页 = 2 GiB，覆盖 Qemu 默认 128MB（最大阶 15）绰绰有余
#define BUDDY_MAX_ORDER 20

static free_area_t free_area[BUDDY_MAX_ORDER];
static size_t nr_free;   // 空闲物理页总数（所有分级链表中页数之和）

static inline size_t order_size(int order) {
    return (size_t)1 << order;
}

/* ---------- 基础操作：入链 / 出链（统一维护 nr_free） ---------- */

// 将大小为 2^order 的空闲块 [base, base + 2^order) 挂入第 order 级链表
static void
buddy_add_block(struct Page *base, int order) {
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
    base->property = order_size(order);
    SetPageProperty(base);
    list_add(&(free_area[order].free_list), &(base->page_link));
    free_area[order].nr_free += order_size(order);
    nr_free += order_size(order);
}

// 从第 order 级链表摘除块 page（要求其确实是该级空闲块头）
static void
buddy_remove_block(struct Page *page, int order) {
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
    assert(PageProperty(page) && page->property == order_size(order));
    list_del(&(page->page_link));
    ClearPageProperty(page);
    free_area[order].nr_free -= order_size(order);
    nr_free -= order_size(order);
}

/* ---------- pmm_manager 接口实现 ---------- */

static void
buddy_init(void) {
    for (int i = 0; i < BUDDY_MAX_ORDER; i ++) {
        list_init(&(free_area[i].free_list));
        free_area[i].nr_free = 0;
    }
    nr_free = 0;
}

static void
buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(PageReserved(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    // 按物理页号自然对齐，将 [base, base+n) 贪心切分为 2^order 的块
    // 伙伴运算基于物理页号，故对齐判断必须使用 page2ppn 得到的 pfn
    size_t pfn = page2ppn(base);
    size_t end = pfn + n;
    while (pfn < end) {
        int order = 0;
        while (order + 1 < BUDDY_MAX_ORDER
               && (pfn & (order_size(order + 1) - 1)) == 0   // 起始 pfn 按 2^(order+1) 对齐
               && pfn + order_size(order + 1) <= end) {       // 且不越过可用区末尾
            order ++;
        }
        buddy_add_block(pages + (pfn - nbase), order);
        pfn += order_size(order);
    }
}

static struct Page *
buddy_alloc_pages(size_t n) {
    assert(n > 0);
    if (n > nr_free) {
        return NULL;
    }
    // 1) 需求向上取整到 2^k
    int order = 0;
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
        order ++;
    }
    if (order_size(order) < n) {
        return NULL;                       // 请求超出最大块
    }
    // 2) 自 k 向上找第一个非空链表
    int cur = order;
    while (cur < BUDDY_MAX_ORDER && list_empty(&(free_area[cur].free_list))) {
        cur ++;
    }
    if (cur == BUDDY_MAX_ORDER) {
        return NULL;                       // 空闲页数够但没有足够大的连续块
    }
    // 3) 摘取一个 2^cur 块
    list_entry_t *le = list_next(&(free_area[cur].free_list));
    struct Page *page = le2page(le, page_link);
    buddy_remove_block(page, cur);
    // 4) 自高向低逐级分裂：每次把右半块放回低一级链表，左半继续分裂
    while (cur > order) {
        cur --;
        struct Page *half = page + order_size(cur);
        buddy_add_block(half, cur);
    }
    page->property = 0;
    set_page_ref(page, 0);
    return page;
}

static void
buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(!PageReserved(p) && !PageProperty(p));   // 防止重复释放/释放保留页
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }
    // 与 alloc 对称：向上取整出本块对应的阶
    int order = 0;
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
        order ++;
    }
    assert(order < BUDDY_MAX_ORDER);

    // 自底向上合并：base 视作"候选块"，每合并一次阶 +1
    struct Page *page = base;
    size_t pfn = page2ppn(page);
    while (order + 1 < BUDDY_MAX_ORDER) {
        size_t buddy_pfn = pfn ^ order_size(order);
        // 伙伴越出本 DRAM 管理范围则不可能合并
        if (buddy_pfn < nbase || buddy_pfn >= npage) {
            break;
        }
        struct Page *buddy = pages + (buddy_pfn - nbase);
        // 伙伴必须是同一阶的空闲块头才能合并：
        // 若它是更大块的头（property 更大）或是别的块的中间页，都不能动
        if (!PageProperty(buddy) || buddy->property != order_size(order)) {
            break;
        }
        // 摘下伙伴，与候选块合并升级
        buddy_remove_block(buddy, order);
        if (buddy < page) {
            page = buddy;                  // 合并块头取地址低者
        }
        pfn = page2ppn(page);
        order ++;
    }
    // 合并到不能再合并，将最终块入链（此处统一入账，净增 = 释放块大小）
    buddy_add_block(page, order);
}

static size_t
buddy_nr_free_pages(void) {
    return nr_free;
}

/* ---------- 正确性检查 ---------- */

static void
buddy_check(void) {
    size_t nr_free_store = nr_free;
    cprintf("buddy_check begin: nr_free = %u\n", nr_free);

    // 1) 单页分配/释放
    struct Page *p0, *p1, *p2;
    assert((p0 = alloc_pages(1)) != NULL);
    assert((p1 = alloc_pages(1)) != NULL);
    assert((p2 = alloc_pages(1)) != NULL);
    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
    assert(page2pa(p0) < npage * PGSIZE);
    free_pages(p0, 1);
    free_pages(p1, 1);
    free_pages(p2, 1);
    assert(nr_free == nr_free_store);

    // 2) 非 2 的幂请求向上取整 + 块对齐检查（5 页 -> order 3，8 页对齐）
    struct Page *p3;
    assert((p3 = alloc_pages(5)) != NULL);
    assert((page2ppn(p3) & (8 - 1)) == 0);
    assert(!PageProperty(p3));
    free_pages(p3, 5);
    assert(nr_free == nr_free_store);

    // 3) 大块分裂再分两半释放，应完全合并回去
    struct Page *p4;
    assert((p4 = alloc_pages(64)) != NULL);
    assert((page2ppn(p4) & (64 - 1)) == 0);
    free_pages(p4, 32);
    free_pages(p4 + 32, 32);
    assert(nr_free == nr_free_store);

    // 4) 压力测试：连续取 64 个单页再逆序归还，页数必须守恒
    struct Page *stress[64];
    int count = 0;
    while (count < 64 && (stress[count] = alloc_pages(1)) != NULL) {
        count ++;
    }
    assert(count == 64);
    while (count > 0) {
        free_pages(stress[--count], 1);
    }
    assert(nr_free == nr_free_store);

    cprintf("buddy_check succeeded!\n");
}

const struct pmm_manager buddy_fit_pmm_manager = {
    .name = "buddy_fit_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};
