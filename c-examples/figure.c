#include <stdint.h>
#include <stdio.h>

#include "../plotille.h"

int main(int argc, char const *argv[]) {
  TermInfo ti;
  if (!get_terminfo(&ti)) {
    printf("Cannot get the terminfo");
    return 1;
  }

  Figure fig;
  if (figure_init(40, 20, color_no_color(), &fig)) {
    figure_set_labels(&fig, "Time", "Value");
    figure_set_limits(&fig, 0.0, 0.0, 10.0, 100.0);

    // Add some data
    double xs[] = {0, 1, 2, 3, 4, 5, 6};
    double ys[] = {0, 10, 40, 50, 40, 10, 0};
    figure_plot(&fig, xs, ys, 7, color_by_name(COLOR_BLUE), "Data", 0);

    // Add annotation
    figure_text(&fig, 2.5, 50.0, "Peak", color_by_name(COLOR_RED));

    figure_axhline(&fig, 0.7, color_by_hsl(30, 0.5, 0.5), 0.0, 1.0);
    figure_axvline(&fig, 0.7, color_by_hsl(30, 0.5, 0.5), 0.0, 1.0);

    // Render and display
    if (figure_prepare(&fig)) {
      uint8_t buffer[8192];
      size_t len = figure_str(fig, buffer, sizeof(buffer));
      if (len > 0) {
        buffer[len] = '\0';
        printf("%s\n", buffer);
      }
    }

    figure_free(&fig);
  }
}
