const std = @import("std");
const BufferTypeId = @import("buffer_type.zig").BufferTypeId;

pub const BufferId = u64;

pub const DestroyFn = *const fn (state: *anyopaque, allocator: std.mem.Allocator) void;

/// Буфер — универсальный контейнер для состояния любого типа.
pub const Buffer = struct {
    id: BufferId,
    type_id: BufferTypeId,
    name: []const u8,
    state: *anyopaque,
    destroy_fn: DestroyFn,

    pub fn create(
        allocator: std.mem.Allocator,
        id: BufferId,
        type_id: BufferTypeId,
        name: []const u8,
        state: *anyopaque,
        destroy_fn: DestroyFn,
    ) !*Buffer {
        const self = try allocator.create(Buffer);
        errdefer allocator.destroy(self);

        self.* = .{
            .id = id,
            .type_id = type_id,
            .name = try allocator.dupe(u8, name),
            .state = state,
            .destroy_fn = destroy_fn,
        };

        return self;
    }

    pub fn destroy(self: *Buffer, allocator: std.mem.Allocator) void {
        self.destroy_fn(self.state, allocator);
        allocator.free(self.name);
        allocator.destroy(self);
    }

    pub fn as(self: *Buffer, comptime T: type) *T {
        return @ptrCast(@alignCast(self.state));
    }
};
