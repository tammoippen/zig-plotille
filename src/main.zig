const std = @import("std");

pub const color = @import("./color.zig");
pub const dots = @import("./dots.zig");
pub const terminfo = @import("./terminfo.zig");
pub const canvas = @import("./canvas.zig");
pub const hist = @import("./hist.zig");
pub const figure = @import("./figure.zig");

comptime {
    _ = color;
    _ = dots;
    _ = terminfo;
    _ = canvas;
    _ = hist;
    _ = figure;
}

// C API

// Dots

export fn dots_init() dots.Dots {
    return dots.Dots{};
}
export fn dots_str(self: dots.Dots, buf: [*]u8, len: usize) usize {
    var fbs = std.io.fixedBufferStream(buf[0..len]);
    std.fmt.format(fbs.writer(), "{s}", .{self}) catch |err| switch (err) {
        error.NoSpaceLeft => return 0,
    };
    return fbs.pos;
}
export fn dots_fill(self: *dots.Dots) void {
    return self.fill();
}
export fn dots_clear(self: *dots.Dots) void {
    return self.clear();
}
export fn dots_set(self: *dots.Dots, x: u8, y: u8) void {
    return self.set(x, y);
}
export fn dots_unset(self: *dots.Dots, x: u8, y: u8) void {
    return self.unset(x, y);
}

// Color

export fn color_no_color() color.Color {
    return color.Color.no_color();
}

export fn color_by_name(name: color.ColorName) color.Color {
    return color.Color.by_name(name);
}

export fn color_by_lookup(idx: u8) color.Color {
    return color.Color.by_lookup(idx);
}

export fn color_by_rgb(r: u8, g: u8, b: u8) color.Color {
    return color.Color.by_rgb(r, g, b);
}

export fn color_by_hsl(h: f64, s: f64, l: f64) color.Color {
    return color.Color.by_hsl(h, s, l);
}

export fn color_str(buf: [*]u8, len: usize, text: [*:0]const u8, options: color.ColorOptions) usize {
    var fbs = std.io.fixedBufferStream(buf[0..len]);
    color.colorPrint(fbs.writer(), "{s}", .{text}, options) catch return 0;
    return fbs.pos;
}

// terminfo

export fn get_terminfo(out: *terminfo.TermInfo) bool {
    if (terminfo.TermInfo.is_set()) {
        out.* = terminfo.TermInfo.get();
        return true;
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    terminfo.TermInfo.detect(allocator) catch return false;
    out.* = terminfo.TermInfo.get();
    return true;
}

// hist

const CHistogram = extern struct {
    counts: ?[*]u32,
    bins: ?[*]f64,
    bins_count: usize,
    bins_capacity: usize,
    delta: f64,
    // Keep a pointer to the original histogram for cleanup
    _internal: ?*anyopaque,
};

export fn hist_init(values: [*]const f64, values_len: usize, bins: usize, out: *CHistogram) bool {
    const allocator = std.heap.c_allocator;

    // Allocate the histogram on the heap
    const hist_ptr = allocator.create(hist.Histogram) catch return false;
    hist_ptr.* = hist.Histogram.init(allocator, values[0..values_len], bins) catch {
        allocator.destroy(hist_ptr);
        return false;
    };

    // Set up the C-compatible structure
    out.counts = hist_ptr.counts.items.ptr;
    out.bins = hist_ptr.bins.items.ptr;
    out.bins_count = hist_ptr.counts.items.len;
    out.bins_capacity = hist_ptr.counts.capacity;
    out.delta = hist_ptr.delta;
    out._internal = hist_ptr;

    return true;
}

export fn hist_free(h: *CHistogram) void {
    const allocator = std.heap.c_allocator;

    if (h._internal) |internal| {
        const hist_ptr: *hist.Histogram = @ptrCast(@alignCast(internal));
        hist_ptr.deinit();
        allocator.destroy(hist_ptr);
    }

    // Reset the structure
    h.* = std.mem.zeroes(CHistogram);
}

export fn hist_str(h: CHistogram, buf: [*]u8, len: usize) usize {
    if (h._internal) |internal| {
        const hist_ptr: *const hist.Histogram = @ptrCast(@alignCast(internal));
        var fbs = std.io.fixedBufferStream(buf[0..len]);
        std.fmt.format(fbs.writer(), "{}", .{hist_ptr.*}) catch return 0;
        return fbs.pos;
    }
    return 0;
}

// canvas

const CCanvas = extern struct {
    width: u16,
    height: u16,
    xmin: f64,
    ymin: f64,
    xmax: f64,
    ymax: f64,
    x_delta_pt: f64,
    y_delta_pt: f64,
    bg: color.Color,
    canvas: ?[*]dots.Dots,
    _internal: ?*anyopaque,
};

export fn canvas_init(width: u16, height: u16, bg: color.Color, out: *CCanvas) bool {
    const allocator = std.heap.c_allocator;

    // Allocate the canvas on the heap
    const canvas_ptr = allocator.create(canvas.Canvas) catch return false;
    canvas_ptr.* = canvas.Canvas.init(allocator, width, height, bg) catch {
        allocator.destroy(canvas_ptr);
        return false;
    };

    // Set up the C-compatible structure
    out.width = canvas_ptr.width;
    out.height = canvas_ptr.height;
    out.xmin = canvas_ptr.xmin;
    out.ymin = canvas_ptr.ymin;
    out.xmax = canvas_ptr.xmax;
    out.ymax = canvas_ptr.ymax;
    out.x_delta_pt = canvas_ptr.x_delta_pt;
    out.y_delta_pt = canvas_ptr.y_delta_pt;
    out.bg = canvas_ptr.bg;
    out.canvas = canvas_ptr.canvas.ptr;
    out._internal = canvas_ptr;

    return true;
}

export fn canvas_free(c: *CCanvas) void {
    const allocator = std.heap.c_allocator;

    if (c._internal) |internal| {
        const canvas_ptr: *canvas.Canvas = @ptrCast(@alignCast(internal));
        canvas_ptr.deinit(allocator);
        allocator.destroy(canvas_ptr);
    }

    // Reset the structure
    c.* = std.mem.zeroes(CCanvas);
}

export fn canvas_set_reference_system(c: *CCanvas, xmin: f64, ymin: f64, xmax: f64, ymax: f64) void {
    if (c._internal) |internal| {
        const canvas_ptr: *canvas.Canvas = @ptrCast(@alignCast(internal));
        canvas_ptr.setReferenceSystem(xmin, ymin, xmax, ymax);

        // Update the C structure fields
        c.xmin = canvas_ptr.xmin;
        c.ymin = canvas_ptr.ymin;
        c.xmax = canvas_ptr.xmax;
        c.ymax = canvas_ptr.ymax;
        c.x_delta_pt = canvas_ptr.x_delta_pt;
        c.y_delta_pt = canvas_ptr.y_delta_pt;
    }
}

export fn canvas_point(c: *CCanvas, p: canvas.Point, fg_color: color.Color, char_override: u8) void {
    if (c._internal) |internal| {
        const canvas_ptr: *canvas.Canvas = @ptrCast(@alignCast(internal));
        const color_opt = if (fg_color.mode == .none) null else fg_color;
        const char_opt = if (char_override == 0) null else char_override;
        canvas_ptr.point(p, color_opt, char_opt);
    }
}

export fn canvas_line(c: *CCanvas, p0: canvas.Point, p1: canvas.Point, fg_color: color.Color, char_override: u8) bool {
    if (c._internal) |internal| {
        const canvas_ptr: *canvas.Canvas = @ptrCast(@alignCast(internal));
        const color_opt = if (fg_color.mode == .none) null else fg_color;
        const char_opt = if (char_override == 0) null else char_override;
        canvas_ptr.line(p0, p1, color_opt, char_opt) catch return false;
        return true;
    }
    return false;
}

export fn canvas_rect(c: *CCanvas, bottom_left: canvas.Point, top_right: canvas.Point, fg_color: color.Color, char_override: u8) bool {
    if (c._internal) |internal| {
        const canvas_ptr: *canvas.Canvas = @ptrCast(@alignCast(internal));
        const color_opt = if (fg_color.mode == .none) null else fg_color;
        const char_opt = if (char_override == 0) null else char_override;
        canvas_ptr.rect(bottom_left, top_right, color_opt, char_opt) catch return false;
        return true;
    }
    return false;
}

export fn canvas_text(c: *CCanvas, p: canvas.Point, text: [*:0]const u8, fg_color: color.Color) void {
    if (c._internal) |internal| {
        const canvas_ptr: *canvas.Canvas = @ptrCast(@alignCast(internal));
        const color_opt = if (fg_color.mode == .none) null else fg_color;
        canvas_ptr.text(p, std.mem.span(text), color_opt);
    }
}

export fn canvas_str(c: CCanvas, buf: [*]u8, len: usize) usize {
    if (c._internal) |internal| {
        const canvas_ptr: *const canvas.Canvas = @ptrCast(@alignCast(internal));
        var fbs = std.io.fixedBufferStream(buf[0..len]);
        std.fmt.format(fbs.writer(), "{}", .{canvas_ptr.*}) catch return 0;
        return fbs.pos;
    }
    return 0;
}
