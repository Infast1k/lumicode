const std = @import("std");
const makeHandler = @import("registry.zig").makeHandler;
const Registry = @import("registry.zig").Registry;
const EditorState = @import("../app/editor.zig").EditorState;

fn quit(state: *EditorState) anyerror!void {
    state.is_running = false;
}

pub fn registerAll(registry: *Registry, state: *EditorState) !void {
    _ = try registry.addHandler(
        "app.quit",
        makeHandler(EditorState, quit, state),
        .{},
    );
}
