const std = @import("std");
const posix = std.posix;

pub const Terminal = struct {
    io: std.Io,
    allocator: std.mem.Allocator,

    original: posix.termios,
    is_raw_mode_enabled: bool = false,

    stdin_buffer: [1024]u8 = undefined,
    stdin_reader: std.Io.File.Reader = undefined,

    stdout_buffer: [1024]u8 = undefined,
    stdout_writer: std.Io.File.Writer = undefined,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !*Terminal {
        const self = try allocator.create(Terminal);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .io = io,
            .original = try posix.tcgetattr(posix.STDIN_FILENO),
            .stdin_reader = std.Io.File.stdin().reader(io, &self.stdin_buffer),
            .stdout_writer = std.Io.File.stdout().writer(io, &self.stdout_buffer),
        };

        return self;
    }

    pub fn deinit(self: *Terminal) void {
        self.flush() catch {};
        self.disableRawMode();
        self.allocator.destroy(self);
    }

    pub fn enterAltScreen(self: *Terminal) !void {
        try self.write("\x1b[?1049h");
    }

    pub fn exitAltScreen(self: *Terminal) !void {
        try self.write("\x1b[?1049l");
    }

    pub fn hideCursor(self: *Terminal) !void {
        try self.write("\x1b[?25l");
    }

    pub fn showCursor(self: *Terminal) !void {
        try self.write("\x1b[?25h");
    }

    pub const Size = struct {
        rows: u16,
        cols: u16,
    };

    pub fn size(self: *Terminal) Size {
        _ = self;
        var ws: posix.winsize = undefined;
        const rc = posix.system.ioctl(
            posix.STDOUT_FILENO,
            posix.T.IOCGWINSZ,
            @intFromPtr(&ws),
        );
        if (rc != 0) return .{ .rows = 24, .cols = 80 };
        return .{ .rows = ws.row, .cols = ws.col };
    }

    pub fn enableRawMode(self: *Terminal) !void {
        if (self.is_raw_mode_enabled) return;

        var raw = self.original;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;

        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;

        raw.oflag.OPOST = false;
        raw.cflag.CSIZE = .CS8;

        raw.cc[@intFromEnum(posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(posix.V.TIME)] = 0;

        try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, raw);
        self.is_raw_mode_enabled = true;
        try self.clearWindow();
    }

    pub fn disableRawMode(self: *Terminal) void {
        if (!self.is_raw_mode_enabled) return;
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.original) catch {};
        self.is_raw_mode_enabled = false;
    }

    pub fn readByte(self: *Terminal) !?u8 {
        return self.stdin_reader.interface.takeByte() catch |err| switch (err) {
            error.EndOfStream => null,
            else => return err,
        };
    }

    pub fn write(self: *Terminal, bytes: []const u8) !void {
        try self.stdout_writer.interface.writeAll(bytes);
    }

    pub fn flush(self: *Terminal) !void {
        try self.stdout_writer.interface.flush();
    }

    pub fn clearWindow(self: *Terminal) !void {
        try self.write("\x1B[H\x1B[2J\x1B[3J");
        try self.flush();
    }
};
