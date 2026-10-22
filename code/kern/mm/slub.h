#ifndef __KERN_MM_SLUB_H__
#define __KERN_MM_SLUB_H__

#include <defs.h>

/* Lab2 C: single-hart, non-reentrant SLUB teaching implementation.
 * Call slub_init after pmm_init. Returned objects are 16-byte aligned and
 * uninitialized. Zero/oversize/OOM allocations return NULL; kfree(NULL) is safe.
 * Only pass the original live allocation pointer to kfree.
 */
#define SLUB_ALIGNMENT 16
#define SLUB_MAX_SMALL_SIZE 2048

void slub_init(void);
void *kmalloc(size_t size);
void kfree(void *ptr);
void slub_check(void);

#endif /* !__KERN_MM_SLUB_H__ */
