const std = @import("std");
const makeHandler = @import("registry.zig").makeHandler;
const Registry = @import("registry.zig").Registry;
const EditorState = @import("../app/editor.zig").EditorState;
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;
const ProjectTree = @import("../buffers/project_tree.zig").ProjectTree;
const TextBuffer = @import("../buffers/text.zig").TextBuffer;

fn currentTree(state: *EditorState) ?*ProjectTree {
    const buf = state.current_buffer orelse return null;
    const tree_type = state.buffer_types.lookup(ProjectTree.TYPE_NAME) orelse return null;
    if (buf.type_id != tree_type) return null;
    return buf.as(ProjectTree);
}

fn openFileInNewBuffer(state: *EditorState, path: []const u8) !void {
    const type_id = state.file_types.resolve(path) orelse {
        std.log.warn("[tree] no buffer type for {s}", .{path});
        return;
    };

    const text_state = try TextBuffer.init(state.gpa, state.io, path);
    const name = std.fs.path.basename(path);
    const buf = try state.createBuffer(type_id, name, text_state, TextBuffer.destroy);
    state.setCurrentBuffer(buf);
    state.last_non_tree_buffer = buf;

    std.log.info("[tree] opened {s} as '{s}'", .{
        path,
        state.buffer_types.get(type_id).name,
    });
}

fn treeUp(state: *EditorState) anyerror!void {
    if (currentTree(state)) |t| t.moveUp();
}
fn treeDown(state: *EditorState) anyerror!void {
    if (currentTree(state)) |t| t.moveDown();
}
fn treeToggle(state: *EditorState) anyerror!void {
    if (currentTree(state)) |t| try t.toggle();
}
fn treeRefresh(state: *EditorState) anyerror!void {
    if (currentTree(state)) |t| try t.refresh();
}

fn treeEnter(state: *EditorState) anyerror!void {
    const tree = currentTree(state) orelse return;
    const node = tree.selectedNode() orelse return;

    if (node.kind == .directory) {
        try tree.toggle();
    } else {
        try openFileInNewBuffer(state, node.path);
    }
}

pub fn registerAll(
    registry: *Registry,
    state: *EditorState,
    tree_type_id: BufferTypeId,
) !void {
    const opts: @import("registry.zig").AddOptions = .{ .buffer_type = tree_type_id };
    _ = try registry.addHandler("tree.up",      makeHandler(EditorState, treeUp,      state), opts);
    _ = try registry.addHandler("tree.down",    makeHandler(EditorState, treeDown,    state), opts);
    _ = try registry.addHandler("tree.toggle",  makeHandler(EditorState, treeToggle,  state), opts);
    _ = try registry.addHandler("tree.enter",   makeHandler(EditorState, treeEnter,   state), opts);
    _ = try registry.addHandler("tree.refresh", makeHandler(EditorState, treeRefresh, state), opts);
}
