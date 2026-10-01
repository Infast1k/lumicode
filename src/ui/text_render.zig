const std = @import("std");
const Terminal = @import("../platform/terminal.zig").Terminal;
const TextBuffer = @import("../buffers/text.zig").TextBuffer;

pub fn render(state: *anyopaque, term: *Terminal) !void {
    const tb: *TextBuffer = @ptrCast(@alignCast(state));
    const size = term.size();

    try term.write("\x1b[2J\x1b[H");

    var it = std.mem.splitScalar(u8, tb.content.items, '\n');
    var row: u16 = 0;
    while (row < size.rows) : (row += 1) {
        const line = it.next() orelse break;
        // Обрезаем \r для Windows-стиля.
        const trimmed = std.mem.trimEnd(u8, line, "\r");
        const len = @min(trimmed.len, size.cols);
        try term.write(trimmed[0..len]);
        if (row + 1 < size.rows) try term.write("\r\n");
    }

    try term.flush();
}
