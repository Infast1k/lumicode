const std = @import("std");

pub const BufferTypeId = u32;

pub const BufferType = struct {
    id: BufferTypeId,
    name: []const u8,
    parent: ?BufferTypeId,
};

pub const BufferTypeRegistry = struct {
    allocator: std.mem.Allocator,
    types: std.ArrayListUnmanaged(BufferType) = .empty,
    by_name: std.StringHashMapUnmanaged(BufferTypeId) = .empty,

    pub fn init(allocator: std.mem.Allocator) BufferTypeRegistry {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BufferTypeRegistry) void {
        for (self.types.items) |t| {
            self.allocator.free(t.name);
        }

        self.types.deinit(self.allocator);
        self.by_name.deinit(self.allocator);
    }

    /// Идемпотентно. `parent` - тип, от которого наследуются команды/рендеры.
    pub fn register(self: *BufferTypeRegistry, name: []const u8, parent: ?BufferTypeId) !BufferTypeId {
        if (self.by_name.get(name)) |id| {
            return id;
        }

        const owned = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned);

        const id: BufferTypeId = @intCast(self.types.items.len);
        try self.types.append(self.allocator, .{
            .id = id,
            .name = owned,
            .parent = parent,
        });

        try self.by_name.put(self.allocator, owned, id);
        return id;
    }

    pub fn lookup(self: *BufferTypeRegistry, name: []const u8) ?BufferTypeId {
        return self.by_name.get(name);
    }

    pub fn get(self: *const BufferTypeRegistry, id: BufferTypeId) BufferType {
        return self.types.items[id];
    }

    /// true, если `child` совпадает с `ancestor` или является его потомком
    pub fn isSubtypeOf(self: *const BufferTypeRegistry, child: BufferTypeId, ancestor: BufferTypeId) bool {
        var cur: ?BufferTypeId = child;
        while (cur) |cid| {
            if (cid == ancestor) return true;
            cur = self.types.items[cid].parent;
        }

        return false;
    }
};
