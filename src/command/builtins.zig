const std = @import("std");
const makeHandler = @import("registry.zig").makeHandler;
const Registry = @import("registry.zig").Registry;
const EditorState = @import("../app/editor.zig").EditorState;
const ProjectTree = @import("../buffers/project_tree.zig").ProjectTree;

fn quit(state: *EditorState) anyerror!void {
    state.is_running = false;
}

fn toggleTree(state: *EditorState) anyerror!void {
    const tree_type = state.buffer_types.lookup(ProjectTree.TYPE_NAME) orelse return;
    const tree_buf = state.findBufferOfType(tree_type) orelse return;
    if (state.current_buffer) |cur| {
        if (cur == tree_buf) {
            if (state.last_non_tree_buffer) |b| {
                state.setCurrentBuffer(b);
            }
        } else {
            state.last_non_tree_buffer = cur;
            state.setCurrentBuffer(tree_buf);
        }
    } else {
        state.setCurrentBuffer(tree_buf);
    }
}

pub fn registerAll(registry: *Registry, state: *EditorState) !void {
    _ = try registry.addHandler(
        "app.quit",
        makeHandler(EditorState, quit, state),
        .{},
    );

    _ = try registry.addHandler(
        "app.toggle-tree",
        makeHandler(EditorState, toggleTree, state),
        .{},
    );
}
