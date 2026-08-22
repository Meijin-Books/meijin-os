/* sync.c -- ミューテックスとセマフォ（第33章2節・4節） */
#include "os.h"

void mutex_lock(mutex_t *m)
{
    unsigned s = irq_disable();
    while (m->locked)
        block_current(&m->waiters);  /* 待機して順番を譲る */
    m->locked = 1;
    irq_restore(s);
}

void mutex_unlock(mutex_t *m)
{
    unsigned s = irq_disable();
    m->locked = 0;
    wake_one(&m->waiters);           /* 待ちタスクを一つ起こす */
    irq_restore(s);
}

void sem_wait(sem_t *s)
{
    unsigned f = irq_disable();
    while (s->count == 0)
        block_current(&s->waiters);  /* 札が尽きたら、待機 */
    s->count--;
    irq_restore(f);
}

void sem_post(sem_t *s)
{
    unsigned f = irq_disable();
    s->count++;
    wake_one(&s->waiters);           /* 待ちタスクを一つ起こす */
    irq_restore(f);
}
