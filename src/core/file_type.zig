const std = @import("std");
const BufferTypeId = @import("buffer_type.zig").BufferTypeId;

/// Маппинг «расширение файла → тип буфера».
pub const FileTypeRegistry = struct {
    allocator: std.mem.Allocator,
    by_extension: std.StringHashMapUnmanaged(BufferTypeId) = .empty,
    default_type: ?BufferTypeId = null,

    pub fn init(allocator: std.mem.Allocator) FileTypeRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FileTypeRegistry) void {
        var it = self.by_extension.keyIterator();
        while (it.next()) |k| self.allocator.free(k.*);
        self.by_extension.deinit(self.allocator);
    }

    /// `ext` без точки, в нижнем регистре: "py", "sql", "zig".
    pub fn registerExtension(
        self: *FileTypeRegistry,
        ext: []const u8,
        type_id: BufferTypeId,
    ) !void {
        const owned = try self.allocator.dupe(u8, ext);
        errdefer self.allocator.free(owned);

        const gop = try self.by_extension.getOrPut(self.allocator, owned);
        if (gop.found_existing) {
            self.allocator.free(owned);
        }
        gop.value_ptr.* = type_id;
    }

    pub fn setDefault(self: *FileTypeRegistry, type_id: BufferTypeId) void {
        self.default_type = type_id;
    }

    pub fn resolve(self: *const FileTypeRegistry, path: []const u8) ?BufferTypeId {
        const raw_ext = std.fs.path.extension(path);
        // Если расширения нет — extension вернёт пустой слайс.
        if (raw_ext.len == 0) return self.default_type;

        const ext = raw_ext[1..]; // отрезаем точку
        var buf: [32]u8 = undefined;
        if (ext.len > buf.len) return self.default_type;

        const lower = std.ascii.lowerString(buf[0..ext.len], ext);
        if (self.by_extension.get(lower)) |id| return id;
        return self.default_type;
    }
};
