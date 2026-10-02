const std = @import("std");
const makeHandler = @import("registry.zig").makeHandler;
const Registry = @import("registry.zig").Registry;
const AddOptions = @import("registry.zig").AddOptions;
const EditorState = @import("../app/editor.zig").EditorState;
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;
const TextBuffer = @import("../buffers/text.zig").TextBuffer;

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
    _ = try registry.addHandler(
        "text.scroll-up",
        makeHandler(EditorState, scrollUp, state),
        .{ .buffer_type = text_type },
    );
    _ = try registry.addHandler(
        "text.scroll-down",
        makeHandler(EditorState, scrollDown, state),
        .{ .buffer_type = text_type },
    );
    _ = try registry.addHandler(
        "text.page-up",
        makeHandler(EditorState, pageUp, state),
        .{ .buffer_type = text_type },
    );
    _ = try registry.addHandler(
        "text.page-down",
        makeHandler(EditorState, pageDown, state),
        .{ .buffer_type = text_type },
    );
}

fn currentText(state: *EditorState) ?*TextBuffer {
    const buf = state.current_buffer orelse return null;
    const text_type = state.buffer_types.lookup(TextBuffer.TYPE_NAME) orelse return null;
    if (!state.buffer_types.isSubtypeOf(buf.type_id, text_type)) return null;
    return buf.as(TextBuffer);
}

fn scrollUp(state: *EditorState) anyerror!void {
    if (currentText(state)) |tb| tb.scrollBy(-3);
}

fn scrollDown(state: *EditorState) anyerror!void {
    if (currentText(state)) |tb| tb.scrollBy(3);
}

fn pageUp(state: *EditorState) anyerror!void {
    if (currentText(state)) |tb| tb.scrollBy(-20);
}

fn pageDown(state: *EditorState) anyerror!void {
    if (currentText(state)) |tb| tb.scrollBy(20);
}
