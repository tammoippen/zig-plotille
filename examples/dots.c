#include <stdio.h>
#include <stdint.h>

#include "zig-plotille.h"

// clang-12 $PWD/zig-out/lib/libzig-plotille.a samples/dots.c -I. -o samples/dots


int main(int argc, char const *argv[])
{
    uint8_t buffer[100];

    struct Dots dot = dots_init();
    dots_set(&dot, 1, 1);
    dots_set(&dot, 1, 2);

    uint8_t len = dots_str(dot, buffer, 100);
    buffer[len] = 0;
    printf("We got: '%s'.\n", buffer);

    return 0;
}
