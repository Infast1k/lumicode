const std = @import("std");
const sdl = @import("zsdl2");
const ttf = @import("zsdl2_ttf");

pub const SdlContext = struct {
    window: *sdl.Window,
    renderer: *sdl.Renderer,
    font: *ttf.Font,

    pub fn init(
        title: [:0]const u8,
        width: u32,
        height: u32,
        font_path: [:0]const u8,
        font_size: u32,
    ) !SdlContext {
        try sdl.init(.{ .video = true, .events = true });
        errdefer sdl.quit();

        const window = try sdl.Window.create(
            title,
            sdl.Window.pos_undefined,
            sdl.Window.pos_undefined,
            @intCast(width),
            @intCast(height),
            .{ .allow_highdpi = true },
        );
        errdefer window.destroy();

        const renderer = try sdl.Renderer.create(window, null, .{ .accelerated = true });
        errdefer renderer.destroy();

        try ttf.init();
        errdefer ttf.quit();

        const font = try ttf.Font.open(font_path, @intCast(font_size));
        errdefer font.close();

        return .{
            .window = window,
            .renderer = renderer,
            .font = font,
        };
    }

    pub fn deinit(self: *SdlContext) void {
        self.font.close();
        ttf.quit();
        self.renderer.destroy();
        self.window.destroy();
        sdl.quit();
    }

    /// Размер окна в логических пикселях.
    pub fn size(self: *SdlContext) struct { w: i32, h: i32 } {
        var w: c_int = 0;
        var h: c_int = 0;
        self.window.getSize(&w, &h);
        return .{ .w = w, .h = h };
    }
};
