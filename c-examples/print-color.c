#include <stdio.h>
#include <stdint.h>

#include "../plotille.h"

int main(int argc, char const *argv[])
{
    uint8_t buffer[256];
    ColorOptions opts = {0};
    opts.fg = color_by_name(COLOR_RED);
    opts.bg = color_by_name(COLOR_BLUE);

    TermInfo ti;
    if (!get_terminfo(&ti))
    {
        printf("Cannot get the terminfo");
        return 1;
    }

    size_t bytes_written = color_str(buffer, sizeof(buffer), "Hello, World!", opts);
    if (bytes_written > 0)
    {
        buffer[bytes_written] = '\0';
        printf("%s\n", buffer); // Print the colored text
    }
}
