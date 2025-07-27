#include <stdint.h>
#include <stdio.h>

#include "../plotille.h"

int main(int argc, char const *argv[]) {
  double data[] = {1.0, 2.0, 3.0, 4.0, 5.0};
  Histogram hist;

  if (hist_init(data, 5, 3, &hist)) {
    uint8_t buffer[32768];
    size_t len = hist_str(hist, buffer, sizeof(buffer));
    if (len > 0) {
      buffer[len] = '\0';
      printf("%s\n", buffer);
    }
    hist_free(&hist);
  }
}
