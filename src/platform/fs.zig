const std = @import("std");

pub const Entry = struct {
    name: []const u8,
    is_dir: bool,
};

const skip_names = [_][]const u8{
    ".git", ".zig-cache", "zig-out", "node_modules", ".DS_Store",
};

pub fn shouldSkip(name: []const u8) bool {
    for (skip_names) |s| {
        if (std.mem.eql(u8, name, s)) return true;
    }
    return false;
}

pub fn listDirectory(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
) !std.ArrayList(Entry) {
    var result = std.ArrayList(Entry).empty;
    errdefer result.deinit(allocator);

    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (shouldSkip(entry.name)) continue;

        const name_copy = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name_copy);

        try result.append(allocator, .{
            .name = name_copy,
            .is_dir = entry.kind == .directory,
        });
    }

    return result;
}

pub fn isDirectory(io: std.Io, path: []const u8) bool {
    var dir = std.Io.Dir.cwd().openDir(io, path, .{}) catch return false;
    dir.close(io);
    return true;
}
