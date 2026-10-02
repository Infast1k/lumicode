const std = @import("std");
const sdl = @import("zsdl2");
const ttf = @import("zsdl2_ttf");
const SdlContext = @import("../platform/sdl.zig").SdlContext;
const TextBuffer = @import("../buffers/text.zig").TextBuffer;

const LINE_HEIGHT: c_int = 22;
const PADDING_TOP: c_int = 8;

pub fn render(state: *anyopaque, ctx: *SdlContext) !void {
    const tb: *TextBuffer = @ptrCast(@alignCast(state));

    try ctx.renderer.setDrawColor(.{ .r = 30, .g = 30, .b = 30, .a = 255 });
    try ctx.renderer.clear();

    const size = ctx.size();
    const viewport_rows: usize = @intCast(@divTrunc(size.h - PADDING_TOP, LINE_HEIGHT));
    if (viewport_rows == 0) {
        ctx.renderer.present();
        return;
    }

    // Итератор по строкам. Пропускаем первые scroll_line строк, потом
    // рисуем viewport_rows. Файл целиком в память уже прочитан — splitScalar
    // лениво идёт по слайсу, не копируя строки.
    var it = std.mem.splitScalar(u8, tb.content.items, '\n');

    var line_idx: usize = 0;
    while (line_idx < tb.scroll_line) : (line_idx += 1) {
        _ = it.next() orelse {
            ctx.renderer.present();
            return;
        };
    }

    var row: usize = 0;
    while (row < viewport_rows) : (row += 1) {
        const line = it.next() orelse break;
        const trimmed = std.mem.trimEnd(u8, line, "\r");

        const y: c_int = PADDING_TOP + @as(c_int, @intCast(row)) * LINE_HEIGHT;

        if (trimmed.len == 0) continue;

        var text_buf: [1024]u8 = undefined;
        if (trimmed.len >= text_buf.len) continue;
        @memcpy(text_buf[0..trimmed.len], trimmed);
        text_buf[trimmed.len] = 0;
        const text_z: [:0]const u8 = text_buf[0..trimmed.len :0];

        const color: sdl.Color = .{ .r = 220, .g = 220, .b = 220, .a = 255 };
        const surface = try ctx.font.renderTextBlended(text_z, color);
        defer sdl.freeSurface(surface);

        const texture = try ctx.renderer.createTextureFromSurface(surface);
        defer sdl.destroyTexture(texture);

        const dst: sdl.Rect = .{
            .x = 10,
            .y = y,
            .w = surface.w,
            .h = surface.h,
        };
        try ctx.renderer.copy(texture, null, &dst);
    }

    ctx.renderer.present();
}
