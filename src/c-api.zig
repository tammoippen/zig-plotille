const std = @import("std");

pub const color = @import("./color.zig");
pub const dots = @import("./dots.zig");
pub const terminfo = @import("./terminfo.zig");
pub const canvas = @import("./canvas.zig");
pub const hist = @import("./hist.zig");
pub const figure = @import("./figure.zig");

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

// figure

const CFigure = extern struct {
    width: u16,
    height: u16,
    xmin: f64,
    ymin: f64,
    xmax: f64,
    ymax: f64,
    origin: bool,
    bg_color: color.Color,
    x_label: ?[*:0]const u8,
    y_label: ?[*:0]const u8,
    _internal: ?*anyopaque,
};

export fn figure_init(width: u16, height: u16, bg_color: color.Color, out: *CFigure) bool {
    const allocator = std.heap.c_allocator;

    // Allocate the figure on the heap
    const figure_ptr = allocator.create(figure.Figure) catch return false;
    const bg_opt = if (bg_color.mode == .none) null else bg_color;
    figure_ptr.* = figure.Figure.init(allocator, width, height, bg_opt) catch {
        allocator.destroy(figure_ptr);
        return false;
    };

    // Set up the C-compatible structure
    out.width = figure_ptr.width;
    out.height = figure_ptr.height;
    out.xmin = figure_ptr.xmin;
    out.ymin = figure_ptr.ymin;
    out.xmax = figure_ptr.xmax;
    out.ymax = figure_ptr.ymax;
    out.origin = figure_ptr.origin;
    out.bg_color = figure_ptr.bg_color;
    out.x_label = @ptrCast(figure_ptr.x_label.ptr);
    out.y_label = @ptrCast(figure_ptr.y_label.ptr);
    out._internal = figure_ptr;

    return true;
}

export fn figure_free(f: *CFigure) void {
    const allocator = std.heap.c_allocator;

    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        figure_ptr.deinit();
        allocator.destroy(figure_ptr);
    }

    // Reset the structure
    f.* = std.mem.zeroes(CFigure);
}

export fn figure_set_labels(f: *CFigure, x_label: [*:0]const u8, y_label: [*:0]const u8) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        const allocator = figure_ptr.allocator;

        // Free old labels
        allocator.free(figure_ptr.x_label);
        allocator.free(figure_ptr.y_label);

        // Allocate new labels
        figure_ptr.x_label = allocator.dupe(u8, std.mem.span(x_label)) catch return false;
        figure_ptr.y_label = allocator.dupe(u8, std.mem.span(y_label)) catch return false;

        // Update C structure pointers
        f.x_label = @ptrCast(figure_ptr.x_label.ptr);
        f.y_label = @ptrCast(figure_ptr.y_label.ptr);

        return true;
    }
    return false;
}

export fn figure_set_limits(f: *CFigure, xmin: f64, ymin: f64, xmax: f64, ymax: f64) void {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        figure_ptr.xmin = xmin;
        figure_ptr.ymin = ymin;
        figure_ptr.xmax = xmax;
        figure_ptr.ymax = ymax;

        // Update C structure
        f.xmin = xmin;
        f.ymin = ymin;
        f.xmax = xmax;
        f.ymax = ymax;
    }
}

export fn figure_plot(f: *CFigure, xs: [*]const f64, ys: [*]const f64, len: usize, plot_color: color.Color, label: ?[*:0]const u8, marker: u8) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        const label_str = if (label) |l| std.mem.span(l) else "Plot";
        const marker_opt = if (marker == 0) null else marker;

        figure_ptr.plot(xs[0..len], ys[0..len], .{
            .lc = plot_color,
            .label = label_str,
            .marker = marker_opt,
        }) catch return false;

        return true;
    }
    return false;
}

export fn figure_scatter(f: *CFigure, xs: [*]const f64, ys: [*]const f64, len: usize, plot_color: color.Color, label: ?[*:0]const u8, marker: u8) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        const label_str = if (label) |l| std.mem.span(l) else "Scatter";
        const marker_char = if (marker == 0) null else marker;

        figure_ptr.scatter(xs[0..len], ys[0..len], .{
            .lc = plot_color,
            .label = label_str,
            .marker = marker_char,
        }) catch return false;

        return true;
    }
    return false;
}

export fn figure_histogram(f: *CFigure, values: [*]const f64, len: usize, bins: usize, hist_color: color.Color) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        const color_opt = if (hist_color.mode == .none) null else hist_color;

        figure_ptr.histogram(values[0..len], bins, color_opt) catch return false;
        return true;
    }
    return false;
}

export fn figure_text(f: *CFigure, x: f64, y: f64, text: [*:0]const u8, text_color: color.Color) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        const color_opt = if (text_color.mode == .none) null else text_color;

        figure_ptr.text(x, y, std.mem.span(text), color_opt) catch return false;
        return true;
    }
    return false;
}

export fn figure_axvline(f: *CFigure, x: f64, line_color: color.Color, ymin: f64, ymax: f64) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));

        figure_ptr.axvline(x, .{
            .lc = line_color,
            .ymin = ymin,
            .ymax = ymax,
        }) catch return false;

        return true;
    }
    return false;
}

export fn figure_axhline(f: *CFigure, y: f64, line_color: color.Color, xmin: f64, xmax: f64) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));

        figure_ptr.axhline(y, .{
            .lc = line_color,
            .xmin = xmin,
            .xmax = xmax,
        }) catch return false;

        return true;
    }
    return false;
}

export fn figure_axvspan(f: *CFigure, xmin: f64, xmax: f64, ymin: f64, ymax: f64, line_color: color.Color) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));

        figure_ptr.axvspan(xmin, xmax, .{
            .lc = line_color,
            .ymin = ymin,
            .ymax = ymax,
        }) catch return false;

        return true;
    }
    return false;
}

export fn figure_prepare(f: *CFigure) bool {
    if (f._internal) |internal| {
        const figure_ptr: *figure.Figure = @ptrCast(@alignCast(internal));
        figure_ptr.prepare() catch return false;
        return true;
    }
    return false;
}

export fn figure_str(f: CFigure, buf: [*]u8, len: usize) usize {
    if (f._internal) |internal| {
        const figure_ptr: *const figure.Figure = @ptrCast(@alignCast(internal));
        var fbs = std.io.fixedBufferStream(buf[0..len]);
        std.fmt.format(fbs.writer(), "{}", .{figure_ptr.*}) catch return 0;
        return fbs.pos;
    }
    return 0;
}
