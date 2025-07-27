#include <stdio.h>
#include <stdint.h>

#include "../plotille.h"

int main(int argc, char const *argv[])
{
    uint8_t buffer[100];

    Dots dot = dots_init();
    dots_set(&dot, 1, 1);
    dots_set(&dot, 1, 2);

    size_t len = dots_str(dot, buffer, 100);
    buffer[len] = 0;
    printf("We got: '%s'.\n", buffer);

    return 0;
}
