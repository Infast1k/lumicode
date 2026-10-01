const std = @import("std");
const Buffer = @import("../core/buffer.zig").Buffer;
const BufferId = @import("../core/buffer.zig").BufferId;
const DestroyFn = @import("../core/buffer.zig").DestroyFn;
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;
const BufferTypeRegistry = @import("../core/buffer_type.zig").BufferTypeRegistry;
const FileTypeRegistry = @import("../core/file_type.zig").FileTypeRegistry;

pub const EditorState = struct {
    gpa: std.mem.Allocator,
    io: std.Io,

    buffers: std.ArrayListUnmanaged(*Buffer) = .empty,
    current_buffer: ?*Buffer = null,

    next_buffer_id: BufferId = 1,

    buffer_types: BufferTypeRegistry,
    file_types: FileTypeRegistry,

    is_running: bool = true,

    pub fn init(gpa: std.mem.Allocator, io: std.Io) EditorState {
        return .{
            .gpa = gpa,
            .io = io,
            .buffer_types = BufferTypeRegistry.init(gpa),
            .file_types = FileTypeRegistry.init(gpa),
        };
    }

    pub fn deinit(self: *EditorState) void {
        for (self.buffers.items) |buf| buf.destroy(self.gpa);
        self.buffers.deinit(self.gpa);
        self.buffer_types.deinit();
        self.file_types.deinit();
    }

    pub fn createBuffer(
        self: *EditorState,
        type_id: BufferTypeId,
        name: []const u8,
        state: *anyopaque,
        destroy_fn: DestroyFn,
    ) !*Buffer {
        const buf = try Buffer.create(
            self.gpa, self.next_buffer_id, type_id, name, state, destroy_fn,
        );
        errdefer buf.destroy(self.gpa);

        self.next_buffer_id += 1;
        try self.buffers.append(self.gpa, buf);
        if (self.current_buffer == null) self.current_buffer = buf;
        return buf;
    }

    pub fn setCurrentBuffer(self: *EditorState, buf: *Buffer) void {
        self.current_buffer = buf;
    }

    pub fn currentTypeId(self: *EditorState) ?BufferTypeId {
        if (self.current_buffer) |buf| return buf.type_id;
        return null;
    }

    pub fn commandContext(self: *EditorState) @import("../command/registry.zig").CommandContext {
        return .{
            .current_type = self.currentTypeId(),
            .types = &self.buffer_types,
        };
    }
};
