const std = @import("std");
const sdl = @import("zsdl2");
const ttf = @import("zsdl2_ttf");
const SdlContext = @import("../platform/sdl.zig").SdlContext;
const TextBuffer = @import("../buffers/text.zig").TextBuffer;

const LINE_HEIGHT: i32 = 22;

pub fn render(state: *anyopaque, ctx: *SdlContext) !void {
    const tb: *TextBuffer = @ptrCast(@alignCast(state));

    try ctx.renderer.setDrawColor(.{ .r = 30, .g = 30, .b = 30, .a = 255 });
    try ctx.renderer.clear();

    const size = ctx.size();
    var y: i32 = 8;

    var it = std.mem.splitScalar(u8, tb.content.items, '\n');
    while (it.next()) |line| {
        if (y > @as(i32, @intCast(size.h)) - LINE_HEIGHT) break;

        const trimmed = std.mem.trimEnd(u8, line, "\r");
        if (trimmed.len == 0) {
            y += LINE_HEIGHT;
            continue;
        }

        var text_buf: [512]u8 = undefined;
        if (trimmed.len >= text_buf.len) {
            y += LINE_HEIGHT;
            continue;
        }
        @memcpy(text_buf[0..line.len], line);
        text_buf[line.len] = 0;
        const text_z: [:0]const u8 = text_buf[0..line.len :0];

        const color: @import("zsdl2").Color = .{
            .r = 220,
            .g = 220,
            .b = 220,
            .a = 255,
        };
        const surface = try ctx.font.renderTextBlended(text_z, color);
        defer sdl.freeSurface(surface);

        const texture = try ctx.renderer.createTextureFromSurface(surface);
        defer texture.destroy();

        const dst: sdl.Rect = .{
            .x = 10,
            .y = y,
            .w = surface.w,
            .h = surface.h,
        };

        try ctx.renderer.copy(texture, null, &dst);

        y += LINE_HEIGHT;
    }

    ctx.renderer.present();
}
