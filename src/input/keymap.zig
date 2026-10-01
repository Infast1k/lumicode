const std = @import("std");
const key_mod = @import("key.zig");
const Registry = @import("../command/registry.zig").Registry;
const BufferTypeRegistry = @import("../core/buffer_type.zig").BufferTypeRegistry;
const CommandContext = @import("../command/registry.zig").CommandContext;

pub const Key = key_mod.Key;

const KeyContext = struct{
    pub fn hash(_: KeyContext, k: Key) u64 {
        return k.hash();
    }

    pub fn eql(_: KeyContext, a: Key, b: Key) bool {
        return a.eql(b);
    }
};

/// Хранит соответствие Key -> имя команды.
/// Ничего не знает про Registry - только про строки.
pub const Keymap = struct {
    allocator: std.mem.Allocator,
    bindings: std.HashMapUnmanaged(
        Key,
        []const u8,
        KeyContext,
        std.hash_map.default_max_load_percentage,
    ) = .empty,

    pub fn init(allocator: std.mem.Allocator) Keymap {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Keymap) void {
        var it = self.bindings.valueIterator();
        while (it.next()) |name_ptr| {
            self.allocator.free(name_ptr.*);
        }

        self.bindings.deinit(self.allocator);
    }

    /// Привязать клавишу к команде. Повторная привязка перезаписывает.
    pub fn bind(self: *Keymap, key: Key, command_name: []const u8) !void {
        const owned = try self.allocator.dupe(u8, command_name);

        const gop = try self.bindings.getOrPut(self.allocator, key);
        if (gop.found_existing) {
            self.allocator.free(gop.value_ptr.*);
        }

        gop.value_ptr.* = owned;
    }

    pub fn unbind(self: *Keymap, key: Key) void {
        if (self.bindings.fetchRemove(key)) |kv| {
            self.allocator.free(kv.value);
        }
    }

    pub fn lookup(self: *Keymap, key: Key) ?[]const u8 {
        return self.bindings.get(key);
    }

    /// Найти и выполнить команду.
    /// true - команда найдена и выполнена | false - клавиша не привязана.
    pub fn dispatch(
        self: *Keymap,
        key: Key,
        registry: *Registry,
        ctx: CommandContext,
    ) !bool {
        const name = self.bindings.get(key) orelse return false;
        return registry.execute(name, ctx);
    }
};
