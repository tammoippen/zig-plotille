#ifndef ZIG_2D_PLOTILLE_H
#define ZIG_2D_PLOTILLE_H

#include <stdint.h>

struct Dots {
    uint8_t dots;
};

#ifdef __cplusplus
extern "C" {
#endif

struct Dots dots_init(void);
uint8_t dots_str(struct Dots self, uint8_t * buf, uintptr_t len);
void dots_fill(struct Dots * self);
void dots_clear(struct Dots * self);
void dots_set(struct Dots * self, uint8_t x, uint8_t y);
void dots_unset(struct Dots * self, uint8_t x, uint8_t y);

#ifdef __cplusplus
} // extern "C"
#endif


#endif // ZIG_2D_PLOTILLE_H
