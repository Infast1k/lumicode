const std = @import("std");
const sdl = @import("zsdl2");
const ttf = @import("zsdl2_ttf");
const SdlContext = @import("../platform/sdl.zig").SdlContext;
const ProjectTree = @import("../buffers/project_tree.zig").ProjectTree;

const LINE_HEIGHT: c_int = 22;
const INDENT_STEP: c_int = 20;

pub fn render(state: *anyopaque, ctx: *SdlContext) !void {
    const tree: *ProjectTree = @ptrCast(@alignCast(state));

    try ctx.renderer.setDrawColor(.{ .r = 30, .g = 30, .b = 30, .a = 255 });
    try ctx.renderer.clear();

    const size = ctx.size();
    const vis = try tree.getVisible();

    var y: c_int = 8;
    for (vis, 0..) |entry, i| {
        if (y > size.h - LINE_HEIGHT) break;
        if (i < tree.scroll) continue;

        const node = entry.node;
        const is_selected = (i == tree.selected);

        if (is_selected) {
            try ctx.renderer.setDrawColor(.{ .r = 60, .g = 60, .b = 90, .a = 255 });
            try ctx.renderer.fillRect(.{
                .x = 0,
                .y = y - 2,
                .w = size.w,
                .h = LINE_HEIGHT,
            });
        }

        var line_buf: [512]u8 = undefined;
        const prefix: []const u8 = if (node.kind == .directory)
            (if (node.expanded) "▼ " else "▶ ")
        else
            "  ";

        const line = std.fmt.bufPrint(&line_buf, "{s}{s}", .{ prefix, node.name }) catch node.name;

        var text_buf: [512]u8 = undefined;
        if (line.len >= text_buf.len) continue;
        @memcpy(text_buf[0..line.len], line);
        text_buf[line.len] = 0;
        const text_z: [:0]const u8 = text_buf[0..line.len :0];

        const color: sdl.Color = if (node.kind == .directory)
            .{ .r = 100, .g = 180, .b = 255, .a = 255 }
        else
            .{ .r = 220, .g = 220, .b = 220, .a = 255 };

        const surface = try ctx.font.renderTextBlended(text_z, color);
        defer sdl.freeSurface(surface);

        const texture = try ctx.renderer.createTextureFromSurface(surface);
        defer sdl.destroyTexture(texture);

        const x: c_int = @as(c_int, @intCast(entry.depth)) * INDENT_STEP + 8;

        const dst: sdl.Rect = .{
            .x = x,
            .y = y,
            .w = surface.w,
            .h = surface.h,
        };

        try ctx.renderer.copy(texture, null, &dst);

        y += LINE_HEIGHT;
    }

    ctx.renderer.present();
}
