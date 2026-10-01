const std = @import("std");
const Buffer = @import("../core/buffer.zig").Buffer;
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;
const BufferTypeRegistry = @import("../core/buffer_type.zig").BufferTypeRegistry;
const SdlContext = @import("../platform/sdl.zig").SdlContext;

pub const RenderFn = *const fn (state: *anyopaque, ctx: *SdlContext) anyerror!void;

pub const RenderRegistry = struct {
    allocator: std.mem.Allocator,
    renderers: std.AutoHashMapUnmanaged(BufferTypeId, RenderFn) = .empty,

    pub fn init(allocator: std.mem.Allocator) RenderRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *RenderRegistry) void {
        self.renderers.deinit(self.allocator);
    }

    pub fn register(self: *RenderRegistry, type_id: BufferTypeId, fn_ptr: RenderFn) !void {
        try self.renderers.put(self.allocator, type_id, fn_ptr);
    }

    pub fn renderBuffer(
        self: *RenderRegistry,
        buf: *Buffer,
        sdl_ctx: *SdlContext,
        types: *const BufferTypeRegistry,
    ) !void {
        var cur: ?BufferTypeId = buf.type_id;
        while (cur) |cid| {
            if (self.renderers.get(cid)) |fn_ptr| {
                try fn_ptr(buf.state, sdl_ctx);
                return;
            }
            cur = types.get(cid).parent;
        }
        // Нет рендерера — просто чистим экран.
        try sdl_ctx.renderer.setDrawColor(.{
            .r = 30,
            .g = 30,
            .b = 30,
            .a = 255,
        });

        try sdl_ctx.renderer.clear();
        sdl_ctx.renderer.present();
    }
};
