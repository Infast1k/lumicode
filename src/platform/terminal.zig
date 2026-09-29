const std = @import("std");
const posix = std.posix;

pub const Terminal = struct {
    original: posix.termios,
    is_raw_mode_enabled: bool = false,

    pub fn init() !Terminal {
        const original = try posix.tcgetattr(posix.STDIN_FILENO);

        var self = Terminal{
            .original = original,
        };

        try self.enableRawMode();

        return self;
    }

    pub fn deinit(self: *Terminal) void {
        self.disableRawMode();
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
    }

    pub fn disableRawMode(self: *Terminal) void {
        if (!self.is_raw_mode_enabled) return;
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.original) catch {};
        self.is_raw_mode_enabled = false;
    }
};
