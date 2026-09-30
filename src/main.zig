const std = @import("std");
const Terminal = @import("platform/terminal.zig").Terminal;
const Parser   = @import("input/parser.zig").Parser;
const Keymap   = @import("input/keymap.zig").Keymap;
const Registry = @import("command/registry.zig").Registry;
const makeHandler = @import("command/registry.zig").makeHandler;
const EditorState = @import("app/editor.zig").EditorState;

fn quitHandler(state: *EditorState) anyerror!void {
    state.running = false;
}

fn markModifiedHandler(state: *EditorState) anyerror!void {
    state.modified = true;
}

fn logHandler(state: *EditorState) anyerror!void {
    std.log.info("[cmd] executed, modified={}", .{state.modified});
}

fn cursorUpHandler(state: *EditorState) anyerror!void {
    _ = state;
    std.log.info("[cmd] cursor up", .{});
}

fn cursorDownHandler(state: *EditorState) anyerror!void {
    _ = state;
    std.log.info("[cmd] cursor down", .{});
}

pub fn main(init: std.process.Init) !void {
    const term = try Terminal.init(init.gpa, init.io);
    defer term.deinit();

    try term.enableRawMode();
    try term.write("Commands demo — Ctrl-Q to quit.\r\n\r\n");
    try term.flush();

    var state = EditorState.init();

    var registry = Registry.init(init.gpa);
    defer registry.deinit();

    try registry.addHandler(
        "app.quit",
        makeHandler(EditorState, quitHandler, &state),
    );
    try registry.addHandler(
        "buffer.edit",
        makeHandler(EditorState, markModifiedHandler, &state),
    );
    try registry.addHandler(
        "buffer.edit",
        makeHandler(EditorState, logHandler, &state),
    );
    try registry.addHandler(
        "cursor.up",
        makeHandler(EditorState, cursorUpHandler, &state),
    );
    try registry.addHandler(
        "cursor.down",
        makeHandler(EditorState, cursorDownHandler, &state),
    );

    var keymap = Keymap.init(init.gpa);
    defer keymap.deinit();

    try keymap.bind(.{ .kind = .char, .char = 'q', .mods = .{ .ctrl = true } }, "app.quit");
    try keymap.bind(.{ .kind = .char, .char = 's', .mods = .{ .ctrl = true } }, "buffer.edit");
    try keymap.bind(.{ .kind = .arrow_up },   "cursor.up");
    try keymap.bind(.{ .kind = .arrow_down }, "cursor.down");

    var parser = Parser.init();

    while (state.running) {
        const byte = try term.readByte() orelse break;
        const key = parser.feed(byte) orelse continue;

        _ = keymap.dispatch(key, &registry) catch |err| {
            std.log.err("command error: {}", .{err});
        };
    }

    try term.write("\r\nBye.\r\n");
    try term.flush();
}
