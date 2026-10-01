const std = @import("std");
const Terminal = @import("../platform/terminal.zig").Terminal;
const Buffer = @import("../core/buffer.zig").Buffer;
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;
const BufferTypeRegistry = @import("../core/buffer_type.zig").BufferTypeRegistry;

pub const RenderFn = *const fn (state: *anyopaque, term: *Terminal) anyerror!void;

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
        term: *Terminal,
        types: *const BufferTypeRegistry,
    ) !void {
        var cur: ?BufferTypeId = buf.type_id;
        while (cur) |cid| {
            if (self.renderers.get(cid)) |fn_ptr| {
                try fn_ptr(buf.state, term);
                return;
            }
            cur = types.get(cid).parent;
        }

        try term.write("\x1b[2J\x1b[H");
        try term.write("[no renderer for this buffer type]\r\n");
        try term.flush();
    }
};
