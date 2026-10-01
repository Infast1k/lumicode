const std = @import("std");
const Terminal = @import("../platform/terminal.zig").Terminal;
const ProjectTree = @import("../buffers/project_tree.zig").ProjectTree;

pub fn render(state: *anyopaque, term: *Terminal) !void {
    const tree: *ProjectTree = @ptrCast(@alignCast(state));

    const size = term.size();
    const vis = try tree.getVisible();

    tree.adjustScroll(size.rows);
    const scroll = tree.scroll;

    try term.write("\x1b[2J\x1b[H");

    var row: u16 = 0;
    while (row < size.rows) : (row += 1) {
        const idx = scroll + row;
        if (idx >= vis.len) break;

        const entry = vis[idx];
        const node = entry.node;
        const is_selected = (idx == tree.selected);

        if (is_selected) try term.write("\x1b[7m");

        var indent: [64]u8 = undefined;
        const indent_len = @min(entry.depth * 2, indent.len);
        @memset(indent[0..indent_len], ' ');
        try term.write(indent[0..indent_len]);

        if (node.kind == .directory) {
            try term.write(if (node.expanded) "▼ " else "▶ ");
        } else {
            try term.write("  ");
        }

        const prefix_width = indent_len + 2;
        const avail = if (size.cols > prefix_width) size.cols - prefix_width else 0;
        const name_len = @min(node.name.len, avail);
        try term.write(node.name[0..name_len]);

        if (is_selected) try term.write("\x1b[0m");
        if (row + 1 < size.rows) try term.write("\r\n");
    }

    try term.flush();
}
