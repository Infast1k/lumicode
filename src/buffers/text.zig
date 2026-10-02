const std = @import("std");

pub const TYPE_NAME = "text";

pub const TextBuffer = struct {
    pub const TYPE_NAME = "text";

    gpa: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    content: std.ArrayListUnmanaged(u8) = .empty,

    /// С какой строки начинается видимая область.
    scroll_line: usize = 0,

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

    /// Общее число строк в буфере (по символу '\n').
    pub fn lineCount(self: *const TextBuffer) usize {
        var count: usize = 1;
        for (self.content.items) |b| {
            if (b == '\n') count += 1;
        }
        return count;
    }

    /// Прокрутить на delta строк. Если delta > 0 — вниз, если < 0 — вверх.
    /// Гарантирует, что scroll_line не выйдет за пределы.
    pub fn scrollBy(self: *TextBuffer, delta: isize) void {
        const total = self.lineCount();
        const new_val: isize = @as(isize, @intCast(self.scroll_line)) + delta;
        self.scroll_line = if (new_val < 0) 0 else if (new_val >= @as(isize, @intCast(total))) total - 1 else @intCast(new_val);
    }

    pub fn scrollTo(self: *TextBuffer, line: usize) void {
        const total = self.lineCount();
        self.scroll_line = @min(line, total - 1);
    }
};
