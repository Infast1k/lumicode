const std = @import("std");
const sdl = @import("zsdl2");
const SdlContext = @import("platform/sdl.zig").SdlContext;
const sdl_input = @import("input/sdl_input.zig");
const Key = @import("input/key.zig").Key;
const Modifier = @import("input/key.zig").Modifier;
const Keymap = @import("input/keymap.zig").Keymap;
const Registry = @import("command/registry.zig").Registry;
const builtins = @import("command/builtins.zig");
const tree_commands = @import("command/tree_commands.zig");
const text_commands = @import("command/text_commands.zig");
const EditorState = @import("app/editor.zig").EditorState;
const ProjectTree = @import("buffers/project_tree.zig").ProjectTree;
const TextBuffer = @import("buffers/text.zig").TextBuffer;
const RenderRegistry = @import("ui/gui_render.zig").RenderRegistry;
const gui_tree_render = @import("ui/gui_tree_render.zig");
const gui_text_render = @import("ui/gui_text_render.zig");

pub fn main(init: std.process.Init) !void {
    // --- SDL ---
    var ctx = try SdlContext.init(
        "lumicode",
        1024,
        768,
        "assets/BlexMonoNerdFont-Regular.ttf",
        16,
    );
    defer ctx.deinit();

    // --- Состояние ---
    var state = EditorState.init(init.gpa, init.io);
    defer state.deinit();

    // Регистрация типов буферов
    const tree_type = try state.buffer_types.register(ProjectTree.TYPE_NAME, null);
    const text_type = try state.buffer_types.register(TextBuffer.TYPE_NAME, null);
    const python_type = try state.buffer_types.register("python", text_type);
    const sql_type = try state.buffer_types.register("sql", text_type);

    try state.file_types.registerExtension("py", python_type);
    try state.file_types.registerExtension("sql", sql_type);
    try state.file_types.registerExtension("txt", text_type);
    state.file_types.setDefault(text_type);

    // Буфер project-tree
    const cwd = try std.process.currentPathAlloc(init.io, init.gpa);
    defer init.gpa.free(cwd);

    const tree = try ProjectTree.init(init.gpa, init.io, cwd);
    _ = try state.createBuffer(tree_type, "project", tree, ProjectTree.destroy);

    // Render registry
    var render_registry = RenderRegistry.init(init.gpa);
    defer render_registry.deinit();
    try render_registry.register(tree_type, gui_tree_render.render);
    try render_registry.register(text_type, gui_text_render.render);

    // Command registry
    var registry = Registry.init(init.gpa);
    defer registry.deinit();
    try builtins.registerAll(&registry, &state);
    try tree_commands.registerAll(&registry, &state, tree_type);
    try text_commands.registerAll(&registry, &state, text_type, python_type, sql_type);

    // Keymap
    var keymap = Keymap.init(init.gpa);
    defer keymap.deinit();

    try keymap.bind(.{ .kind = .char, .char = 'q', .mods = .{ .ctrl = true } }, "app.quit");
    try keymap.bind(.{ .kind = .arrow_up }, "tree.up");
    try keymap.bind(.{ .kind = .arrow_down }, "tree.down");
    try keymap.bind(.{ .kind = .arrow_right }, "tree.toggle");
    try keymap.bind(.{ .kind = .arrow_left }, "tree.toggle");
    try keymap.bind(.{ .kind = .enter }, "tree.enter");
    try keymap.bind(.{ .kind = .char, .char = 'r', .mods = .{ .ctrl = true } }, "tree.refresh");
    try keymap.bind(.{ .kind = .char, .char = 's', .mods = .{ .ctrl = true } }, "text.save");
    try keymap.bind(.{ .kind = .char, .char = 'p', .mods = .{ .ctrl = true } }, "python.run");
    try keymap.bind(.{ .kind = .char, .char = 'e', .mods = .{ .ctrl = true } }, "sql.execute");
    try keymap.bind(.{ .kind = .char, .char = 'b', .mods = .{ .ctrl = true } }, "app.toggle-tree");
    try keymap.bind(.{ .kind = .page_up }, "text.page-up");
    try keymap.bind(.{ .kind = .page_down }, "text.page-down");
    try keymap.bind(
        .{ .kind = .arrow_up, .mods = .{ .ctrl = true } },
        "text.scroll-up",
    );
    try keymap.bind(
        .{ .kind = .arrow_down, .mods = .{ .ctrl = true } },
        "text.scroll-down",
    );

    // --- Первый кадр ---
    if (state.current_buffer) |buf| {
        try render_registry.renderBuffer(buf, &ctx, &state.buffer_types);
    }

    // --- Event loop ---
    var last_mods = Modifier{};

    while (state.is_running) {
        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            switch (event.type) {
                .quit => state.is_running = false,
                .keydown => {
                    const k = event.key;
                    last_mods = sdl_input.modsFromSdl(k.keysym.mod);
                    if (sdl_input.keyFromKeyDown(k)) |key| {
                        _ = keymap.dispatch(key, &registry, state.commandContext()) catch |err| {
                            std.log.err("command error: {}", .{err});
                        };
                    }
                },
                .textinput => {
                    const t = event.text;
                    if (sdl_input.keyFromTextInput(t, last_mods)) |key| {
                        _ = keymap.dispatch(key, &registry, state.commandContext()) catch |err| {
                            std.log.err("command error: {}", .{err});
                        };
                    }
                },
                else => {},
            }
        }

        if (state.current_buffer) |buf| {
            try render_registry.renderBuffer(buf, &ctx, &state.buffer_types);
        }

        sdl.delay(16); // ~60 FPS
    }
}
