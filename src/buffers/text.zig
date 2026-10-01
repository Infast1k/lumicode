const std = @import("std");

pub const TYPE_NAME = "text";

pub const TextBuffer = struct {
    pub const TYPE_NAME = "text";

    gpa: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    content: std.ArrayListUnmanaged(u8) = .empty,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !*TextBuffer {
        const self = try gpa.create(TextBuffer);
        errdefer gpa.destroy(self);

        self.* = .{
            .gpa = gpa,
            .io = io,
            .path = try gpa.dupe(u8, path),
        };

        // Пытаемся прочитать файл; если не получилось — оставляем пустым.

        const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch return self;
        defer file.close(io);

        var buf: [4096]u8 = undefined;
        while (true) {
            const n = file.readStreaming(io, &.{&buf}) catch |err| switch (err) {
                error.EndOfStream => break,
                else => break,
            };
            if (n == 0) break;
            try self.content.appendSlice(gpa, buf[0..n]);
        }

        return self;
    }

    pub fn deinit(self: *TextBuffer) void {
        const gpa = self.gpa;
        self.content.deinit(gpa);
        gpa.free(self.path);
        gpa.destroy(self);
    }

    pub fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        _ = allocator;
        const self: *TextBuffer = @ptrCast(@alignCast(state));
        self.deinit();
    }
};
