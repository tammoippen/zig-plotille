#ifndef ZIG_PLOTILLE_H
#define ZIG_PLOTILLE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================================
// Color Types and Enums
// ============================================================================

/**
 * Color mode enumeration corresponding to Zig's ColorMode enum
 */
typedef enum {
    COLOR_MODE_NONE = 0,
    COLOR_MODE_NAMES = 1,
    COLOR_MODE_LOOKUP = 2,
    COLOR_MODE_RGB = 3
} ColorMode;

/**
 * Color name enumeration corresponding to Zig's ColorName enum
 */
typedef enum {
    COLOR_BLACK = 0,
    COLOR_RED = 1,
    COLOR_GREEN = 2,
    COLOR_YELLOW = 3,
    COLOR_BLUE = 4,
    COLOR_MAGENTA = 5,
    COLOR_CYAN = 6,
    COLOR_WHITE = 7,
    COLOR_BRIGHT_BLACK = 8,
    COLOR_BRIGHT_RED = 9,
    COLOR_BRIGHT_GREEN = 10,
    COLOR_BRIGHT_YELLOW = 11,
    COLOR_BRIGHT_BLUE = 12,
    COLOR_BRIGHT_MAGENTA = 13,
    COLOR_BRIGHT_CYAN = 14,
    COLOR_BRIGHT_WHITE = 15,
    COLOR_BRIGHT_BLACK_OLD = 16,
    COLOR_BRIGHT_RED_OLD = 17,
    COLOR_BRIGHT_GREEN_OLD = 18,
    COLOR_BRIGHT_YELLOW_OLD = 19,
    COLOR_BRIGHT_BLUE_OLD = 20,
    COLOR_BRIGHT_MAGENTA_OLD = 21,
    COLOR_BRIGHT_CYAN_OLD = 22,
    COLOR_BRIGHT_WHITE_OLD = 23,
    COLOR_INVALID = 24
} ColorName;

/**
 * Color structure corresponding to Zig's Color extern struct
 */
typedef struct {
    ColorMode mode;
    ColorName name;
    uint8_t lookup;
    uint8_t rgb[3];
} Color;

/**
 * Color options structure corresponding to Zig's ColorOptions extern struct
 */
typedef struct {
    bool reset_all;
    Color fg;
    Color bg;
} ColorOptions;

/**
 * Dots structure corresponding to Zig's Dots extern struct
 * Represents a braille character with optional color and custom character override
 */
typedef struct {
    uint8_t dots;        /* Braille dot pattern (0-255) */
    uint8_t char_override; /* Custom character override (0 = use braille) */
    ColorOptions color;  /* Color options for foreground/background */
} Dots;

/**
 * Terminal information structure corresponding to Zig's TermInfo extern struct
 */
typedef struct {
    bool stdout_tty;             /* Whether stdout is a TTY/interactive */
    bool no_color;               /* Respect NO_COLOR environment variable */
    bool force_color;            /* Force color output regardless of TTY status */
    ColorMode suggested_color_mode; /* Detected optimal color mode for terminal */
} TermInfo;

// ============================================================================
// Exported Functions
// ============================================================================

/**
 * Initialize a new Dots structure with default values
 * @return Initialized Dots structure
 */
Dots dots_init(void);

/**
 * Convert a Dots structure to its string representation
 * @param self The Dots structure to convert
 * @param buf Buffer to write the string representation to
 * @param len Length of the buffer
 * @return Number of bytes written to the buffer, or 0 if buffer too small
 */
size_t dots_str(Dots self, uint8_t *buf, size_t len);

/**
 * Fill all dots in the braille character (set all 8 dots)
 * @param self Pointer to the Dots structure to modify
 */
void dots_fill(Dots *self);

/**
 * Clear all dots and reset character override
 * @param self Pointer to the Dots structure to modify
 */
void dots_clear(Dots *self);

/**
 * Set a specific dot in the braille character
 * @param self Pointer to the Dots structure to modify
 * @param x X coordinate (0 or 1)
 * @param y Y coordinate (0, 1, 2, or 3)
 */
void dots_set(Dots *self, uint8_t x, uint8_t y);

/**
 * Unset a specific dot in the braille character
 * @param self Pointer to the Dots structure to modify
 * @param x X coordinate (0 or 1)
 * @param y Y coordinate (0, 1, 2, or 3)
 */
void dots_unset(Dots *self, uint8_t x, uint8_t y);

/**
 * Create a Color by name
 * @param name Color name from ColorName enum
 * @return Color structure with the specified name
 */
Color color_by_name(ColorName name);

/**
 * Create a Color with no color
 * @return Color structure representing no color
 */
Color color_no_color(void);

/**
 * Create a Color using 8-bit color lookup table (0-255)
 * @param lookup Color index in 8-bit color palette
 * @return Color structure with the specified lookup index
 */
Color color_by_lookup(uint8_t lookup);

/**
 * Create a Color using 24-bit RGB values
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @return Color structure with the specified RGB values
 */
Color color_by_rgb(uint8_t r, uint8_t g, uint8_t b);

/**
 * Create a Color using HSL (Hue, Saturation, Lightness) values
 * @param h Hue (0.0-360.0 degrees)
 * @param s Saturation (0.0-1.0)
 * @param l Lightness (0.0-1.0)
 * @return Color structure converted from HSL to RGB
 */
Color color_by_hsl(double h, double s, double l);

/**
 * Get terminal information by detecting capabilities from environment
 * @param out Pointer to TermInfo structure to fill with detected capabilities
 * @return true if detection succeeded, false on error
 */
bool get_terminfo(TermInfo *out);

/**
 * Print text with color formatting to a buffer
 * @param buf Output buffer to write colored text to
 * @param len Size of the output buffer
 * @param text Null-terminated text to print with colors
 * @param options Color options for foreground/background
 * @return Number of bytes written to buffer, or 0 if buffer too small
 */
size_t color_print(uint8_t *buf, size_t len, const char *text, ColorOptions options);

// ============================================================================
// Helper Functions and Constants
// ============================================================================

/**
 * Braille character dot layout:
 *
 * Position mapping for set/unset functions:
 * (0,0) (1,0)  ->  Dot 0  Dot 3
 * (0,1) (1,1)  ->  Dot 1  Dot 4
 * (0,2) (1,2)  ->  Dot 2  Dot 5
 * (0,3) (1,3)  ->  Dot 6  Dot 7
 *
 * Each braille character can represent 2x4 dots (8 total)
 * Unicode range: U+2800 (⠀) to U+28FF (⣿)
 */

/**
 * Library version and build information
 */
#define PLOTILLE_VERSION_MAJOR 0
#define PLOTILLE_VERSION_MINOR 0
#define PLOTILLE_VERSION_PATCH 1

#ifdef __cplusplus
}
#endif

#endif /* ZIG_PLOTILLE_H */
