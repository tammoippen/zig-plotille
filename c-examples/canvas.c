#include <stdint.h>
#include <stdio.h>

#include "../plotille.h"

int main(int argc, char const *argv[])
{

  TermInfo ti;
  if (!get_terminfo(&ti))
  {
    printf("Cannot get the terminfo");
    return 1;
  }

  Canvas canvas;
  if (canvas_init(40, 20, color_by_rgb(100, 100, 100), &canvas))
  {
    canvas_set_reference_system(&canvas, -1.0, -1.0, 1.0, 1.0);
    
    Point p0 = {0.4, 0.4};
    Point p1 = {0.0, 0.0};
    Point p2 = {0.5, 0.8};
    Point p3 = {-0.5, -0.3};
    canvas_point(&canvas, p0, color_by_name(COLOR_RED), 0);
    canvas_line(&canvas, p1, p2, color_by_name(COLOR_BLUE), 0);
    canvas_rect(&canvas, p1, p2, color_by_name(COLOR_GREEN), 0);
    canvas_text(&canvas, p3, "Hello", color_by_lookup(131));

    uint8_t buffer[32768];
    size_t len = canvas_str(canvas, buffer, sizeof(buffer));
    if (len > 0)
    {
      buffer[len] = '\0';
      printf("%s\n", buffer);
    }

    canvas_free(&canvas);
  }

  return 0;
}
