const std = @import("std");
const EditorState = @import("editor.zig");

/// Контекст, передающийся в команды и обработчики
pub const Context = EditorState;
