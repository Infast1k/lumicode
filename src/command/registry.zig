const std = @import("std");
const BufferTypeId = @import("../core/buffer_type.zig").BufferTypeId;
const BufferTypeRegistry = @import("../core/buffer_type.zig").BufferTypeRegistry;

pub const HandlerFn = *const fn (ctx: *anyopaque) anyerror!void;
pub const DestroyFn = *const fn (ctx: *anyopaque, allocator: std.mem.Allocator) void;

pub const Handler = struct {
    func: HandlerFn,
    ctx: *anyopaque,
    on_destroy: ?DestroyFn = null,

    pub fn call(self: Handler) !void {
        try self.func(self.ctx);
    }
};

pub const ScopedHandler = struct {
    handler: Handler,
    buffer_type: ?BufferTypeId = null,
};

/// Контекст выполнения команды.
pub const CommandContext = struct {
    current_type: ?BufferTypeId,
    types: *const BufferTypeRegistry,
};

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    handlers: std.ArrayListUnmanaged(ScopedHandler) = .empty,

    pub fn execute(self: *Command, ctx: CommandContext) !void {
        for (self.handlers.items) |sh| {
            if (sh.buffer_type) |required| {
                const current = ctx.current_type orelse continue;
                if (!ctx.types.isSubtypeOf(current, required)) continue;
            }
            try sh.handler.call();
        }
    }
};

pub const AddOptions = struct {
    buffer_type: ?BufferTypeId = null,
};

pub const Registry = struct {
    allocator: std.mem.Allocator,
    commands: std.StringHashMapUnmanaged(*Command) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        var it = self.commands.valueIterator();
        while (it.next()) |cmd_ptr| {
            const cmd = cmd_ptr.*;
            for (cmd.handlers.items) |sh| {
                if (sh.handler.on_destroy) |d| d(sh.handler.ctx, self.allocator);
            }
            cmd.handlers.deinit(self.allocator);
            self.allocator.free(cmd.name);
            self.allocator.free(cmd.description);
            self.allocator.destroy(cmd);
        }
        self.commands.deinit(self.allocator);
    }

    pub fn register(self: *Registry, name: []const u8, description: []const u8) !*Command {
        if (self.commands.get(name)) |existing| return existing;

        const cmd = try self.allocator.create(Command);
        errdefer self.allocator.destroy(cmd);

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_desc = try self.allocator.dupe(u8, description);
        errdefer self.allocator.free(owned_desc);

        cmd.* = .{ .name = owned_name, .description = owned_desc };
        try self.commands.put(self.allocator, owned_name, cmd);
        return cmd;
    }

    pub fn addHandler(
        self: *Registry,
        command_name: []const u8,
        handler: Handler,
        options: AddOptions,
    ) !*Command {
        const cmd = self.commands.get(command_name) orelse
            try self.register(command_name, "");
        try cmd.handlers.append(self.allocator, .{
            .handler = handler,
            .buffer_type = options.buffer_type,
        });
        return cmd;
    }

    pub fn execute(self: *Registry, name: []const u8, ctx: CommandContext) !bool {
        const cmd = self.commands.get(name) orelse return false;
        try cmd.execute(ctx);
        return true;
    }

    pub fn get(self: *Registry, name: []const u8) ?*Command {
        return self.commands.get(name);
    }
};

pub fn makeHandler(
    comptime Ctx: type,
    comptime func: *const fn (*Ctx) anyerror!void,
    ctx: *Ctx,
) Handler {
    const wrapper = struct {
        fn call(raw: *anyopaque) anyerror!void {
            const typed: *Ctx = @ptrCast(@alignCast(raw));
            return func(typed);
        }
    };
    return .{ .func = wrapper.call, .ctx = @ptrCast(ctx) };
}
