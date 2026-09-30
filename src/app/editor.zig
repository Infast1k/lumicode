const std = @import("std");

pub const EditorState = struct {
    running: bool = true,
    modified: bool = false,

    pub fn init() EditorState {
        return .{};
    }
};
