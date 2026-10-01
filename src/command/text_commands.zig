const std = @import("std");
const makeHandler = @import("registry.zig").makeHandler;
const Registry = @import("registry.zig").Registry;
const AddOptions = @import("registry.zig").AddOptions;
const EditorState = @import("../app/editor.zig").EditorState;
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;

// text.save — сработает на любом буфере, чей тип наследуется от "text".
fn textSave(state: *EditorState) anyerror!void {
    const buf = state.current_buffer orelse return;
    std.log.info("[text] save stub for '{s}'", .{buf.name});
}

// python.run — только на python.
fn pythonRun(state: *EditorState) anyerror!void {
    const buf = state.current_buffer orelse return;
    std.log.info("[python] run stub for '{s}'", .{buf.name});
}

// sql.execute — только на sql.
fn sqlExecute(state: *EditorState) anyerror!void {
    const buf = state.current_buffer orelse return;
    std.log.info("[sql] execute stub for '{s}'", .{buf.name});
}

pub fn registerAll(
    registry: *Registry,
    state: *EditorState,
    text_type: BufferTypeId,
    python_type: BufferTypeId,
    sql_type: BufferTypeId,
) !void {
    _ = try registry.addHandler(
        "text.save",
        makeHandler(EditorState, textSave, state),
        .{ .buffer_type = text_type },
    );
    _ = try registry.addHandler(
        "python.run",
        makeHandler(EditorState, pythonRun, state),
        .{ .buffer_type = python_type },
    );
    _ = try registry.addHandler(
        "sql.execute",
        makeHandler(EditorState, sqlExecute, state),
        .{ .buffer_type = sql_type },
    );
}
