const std = @import("std");
const Terminal = @import("platform/terminal.zig").Terminal;
const Parser   = @import("input/parser.zig").Parser;
const Keymap   = @import("input/keymap.zig").Keymap;
const Registry = @import("command/registry.zig").Registry;
const builtins = @import("command/builtins.zig");
const tree_commands = @import("command/tree_commands.zig");
const text_commands = @import("command/text_commands.zig");
const EditorState = @import("app/editor.zig").EditorState;
const ProjectTree = @import("buffers/project_tree.zig").ProjectTree;
const TextBuffer = @import("buffers/text.zig").TextBuffer;
const RenderRegistry = @import("ui/render.zig").RenderRegistry;
const tree_render = @import("ui/tree_render.zig");
const text_render = @import("ui/text_render.zig");

pub fn main(init: std.process.Init) !void {
    const term = try Terminal.init(init.gpa, init.io);
    defer term.deinit();

    try term.enableRawMode();
    try term.enterAltScreen();
    defer term.exitAltScreen() catch {};
    try term.hideCursor();
    defer term.showCursor() catch {};

    var state = EditorState.init(init.gpa, init.io);
    defer state.deinit();

    // --- Регистрация типов буферов ---
    // "project-tree" — самостоятельный тип без родителя.
    const tree_type = try state.buffer_types.register(ProjectTree.TYPE_NAME, null);

    // "text" — базовый тип для всех файлов.
    const text_type = try state.buffer_types.register(TextBuffer.TYPE_NAME, null);

    // "python" и "sql" наследуются от "text".
    const python_type = try state.buffer_types.register("python", text_type);
    const sql_type    = try state.buffer_types.register("sql",    text_type);

    // --- Расширения → типы ---
    try state.file_types.registerExtension("py",  python_type);
    try state.file_types.registerExtension("sql", sql_type);
    try state.file_types.registerExtension("txt", text_type);
    state.file_types.setDefault(text_type);

    // --- Буфер "project-tree" ---
    const cwd = try std.process.currentPathAlloc(init.io, init.gpa);
    defer init.gpa.free(cwd);

    const tree = try ProjectTree.init(init.gpa, init.io, cwd);
    _ = try state.createBuffer(tree_type, "project", tree, ProjectTree.destroy);

    // --- Render registry ---
    var render_registry = RenderRegistry.init(init.gpa);
    defer render_registry.deinit();
    try render_registry.register(tree_type, tree_render.render);
    try render_registry.register(text_type, text_render.render);
    // python и sql не регистрируем — рендер унаследуется от text.

    // --- Command registry ---
    var registry = Registry.init(init.gpa);
    defer registry.deinit();

    try builtins.registerAll(&registry, &state);
    try tree_commands.registerAll(&registry, &state, tree_type);
    try text_commands.registerAll(&registry, &state, text_type, python_type, sql_type);

    // --- Keymap ---
    var keymap = Keymap.init(init.gpa);
    defer keymap.deinit();

    try keymap.bind(.{ .kind = .char, .char = 'q', .mods = .{ .ctrl = true } }, "app.quit");
    try keymap.bind(.{ .kind = .arrow_up },    "tree.up");
    try keymap.bind(.{ .kind = .arrow_down },  "tree.down");
    try keymap.bind(.{ .kind = .arrow_right }, "tree.toggle");
    try keymap.bind(.{ .kind = .arrow_left },  "tree.toggle");
    try keymap.bind(.{ .kind = .enter },       "tree.enter");
    try keymap.bind(.{ .kind = .char, .char = 'r', .mods = .{ .ctrl = true } }, "tree.refresh");

    try keymap.bind(.{ .kind = .char, .char = 's', .mods = .{ .ctrl = true } }, "text.save");
    try keymap.bind(.{ .kind = .char, .char = 'p', .mods = .{ .ctrl = true } }, "python.run");
    try keymap.bind(.{ .kind = .char, .char = 'e', .mods = .{ .ctrl = true } }, "sql.execute");

    var parser = Parser.init();

    try render_registry.renderBuffer(state.current_buffer.?, term, &state.buffer_types);

    while (state.is_running) {
        const byte = try term.readByte() orelse break;
        const key = parser.feed(byte) orelse continue;

        _ = keymap.dispatch(key, &registry, state.commandContext()) catch |err| {
            std.log.err("command error: {}", .{err});
        };

        if (state.current_buffer) |buf| {
            try render_registry.renderBuffer(buf, term, &state.buffer_types);
        }
    }
}
