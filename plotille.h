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

/**
 * C-compatible Histogram structure
 * Represents a histogram with raw pointer arrays instead of ArrayList
 */
typedef struct {
    uint32_t *counts;       /* Array of count values for each bin (nullable) */
    double *bins;           /* Array of bin boundaries (bins_count + 1 elements, nullable) */
    size_t bins_count;      /* Number of bins */
    size_t bins_capacity;   /* Capacity of the arrays */
    double delta;           /* Range of the histogram (max - min) */
    void *_internal;        /* Internal pointer for memory management (do not modify) */
} Histogram;

/**
 * Coordinate structures matching Zig extern structs
 */

/**
 * Point structure for 2D coordinates
 */
typedef struct {
    double x;
    double y;
} Point;

/**
 * Point distance structure for coordinate differences
 */
typedef struct {
    intptr_t x;
    intptr_t y;
} PointDistance;

/**
 * C-compatible Canvas structure for 2D plotting
 * Maintains both character-based dimensions and reference coordinate system
 */
typedef struct {
    uint16_t width;          /* Width in characters */
    uint16_t height;         /* Height in characters */
    double xmin, ymin;       /* Lower left corner of reference system */
    double xmax, ymax;       /* Upper right corner of reference system */
    double x_delta_pt;       /* X value between dots */
    double y_delta_pt;       /* Y value between dots */
    Color bg;                /* Background color */
    Dots *canvas;            /* Array of Dots (width * height elements) */
    void *_internal;         /* Internal pointer for memory management (do not modify) */
} Canvas;

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
size_t color_str(uint8_t *buf, size_t len, const char *text, ColorOptions options);

/**
 * Initialize a histogram from an array of values
 * @param values Array of input values to create histogram from
 * @param values_len Number of values in the input array
 * @param bins Number of bins to divide the data into
 * @param out Pointer to Histogram structure to initialize
 * @return true if initialization succeeded, false on error
 */
bool hist_init(const double *values, size_t values_len, size_t bins, Histogram *out);

/**
 * Free memory allocated for a histogram
 * @param h Pointer to the Histogram structure to free
 */
void hist_free(Histogram *h);

/**
 * Convert histogram to string representation
 * @param h Histogram structure to convert
 * @param buf Buffer to write the string representation to
 * @param len Length of the buffer
 * @return Number of bytes written to buffer, or 0 if buffer too small
 */
size_t hist_str(Histogram h, uint8_t *buf, size_t len);

/**
 * Initialize a canvas with specified dimensions and background color
 * @param width Width in characters
 * @param height Height in characters
 * @param bg Background color
 * @param out Pointer to Canvas structure to initialize
 * @return true if initialization succeeded, false on error
 */
bool canvas_init(uint16_t width, uint16_t height, Color bg, Canvas *out);

/**
 * Free memory allocated for a canvas
 * @param canvas Pointer to the Canvas structure to free
 */
void canvas_free(Canvas *canvas);

/**
 * Set the reference coordinate system for the canvas
 * @param canvas Pointer to the Canvas structure
 * @param xmin Minimum x coordinate
 * @param ymin Minimum y coordinate
 * @param xmax Maximum x coordinate
 * @param ymax Maximum y coordinate
 */
void canvas_set_reference_system(Canvas *canvas, double xmin, double ymin, double xmax, double ymax);

/**
 * Plot a single point on the canvas
 * @param canvas Pointer to the Canvas structure
 * @param p Point coordinates in reference system
 * @param fg_color Foreground color (pass color_no_color() for default)
 * @param char_override Character to display instead of braille dot (0 for braille)
 */
void canvas_point(Canvas *canvas, Point p, Color fg_color, uint8_t char_override);

/**
 * Draw a line between two points on the canvas
 * @param canvas Pointer to the Canvas structure
 * @param p0 Starting point in reference system
 * @param p1 Ending point in reference system
 * @param fg_color Foreground color (pass color_no_color() for default)
 * @param char_override Character for line endpoints (0 for braille)
 * @return true if successful, false on error
 */
bool canvas_line(Canvas *canvas, Point p0, Point p1, Color fg_color, uint8_t char_override);

/**
 * Draw a rectangle on the canvas
 * @param canvas Pointer to the Canvas structure
 * @param bottom_left Bottom-left corner in reference system
 * @param top_right Top-right corner in reference system
 * @param fg_color Foreground color (pass color_no_color() for default)
 * @param char_override Character for rectangle corners (0 for braille)
 * @return true if successful, false on error
 */
bool canvas_rect(Canvas *canvas, Point bottom_left, Point top_right, Color fg_color, uint8_t char_override);

/**
 * Add text to the canvas at specified position
 * @param canvas Pointer to the Canvas structure
 * @param p Position in reference system
 * @param text Null-terminated text string
 * @param fg_color Foreground color (pass color_no_color() for default)
 */
void canvas_text(Canvas *canvas, Point p, const char *text, Color fg_color);

/**
 * Convert canvas to string representation
 * @param canvas Canvas structure to convert
 * @param buf Buffer to write the string representation to
 * @param len Length of the buffer
 * @return Number of bytes written to buffer, or 0 if buffer too small
 */
size_t canvas_str(Canvas canvas, uint8_t *buf, size_t len);

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
