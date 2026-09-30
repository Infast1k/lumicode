const std = @import("std");

/// Указатель на функцию-обработчик. ctx - произвольный контекст,
/// который обработчик сам кастует к нужному типу.
pub const HandlerFn = *const fn (ctx: *anyopaque) anyerror!void;

/// Деструктор контекста. Вызывается Registry при удалении обработчика.
/// Для нативных обработчиков обычно null (ctx не владеет памятью).
/// Для скриптовых (Lua) - освобождает выделенный ctx.
pub const DestroyFn = *const fn (ctx: *anyopaque, allocator: std.mem.Allocator) void;

pub const Handler = struct {
    func: HandlerFn,
    ctx: *anyopaque,
    on_destroy: ?DestroyFn = null,

    pub fn call(self: Handler) !void {
        try self.func(self.ctx);
    }
};

pub const Command = struct {
    name: []const u8,
    description: []const u8,
    handlers: std.ArrayListUnmanaged(Handler) = .empty,

    pub fn execute(self: *Command) !void {
        for (self.handlers.items) |h| {
            try h.call();
        }
    }
};

pub const Registry = struct {
    allocator: std.mem.Allocator,
    commands: std.StringHashMapUnmanaged(*Command) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Registry) void {
        var it = self.commands.valueIterator();
        while (it.next()) |cmd_ptr| {
            const cmd = cmd_ptr.*;
            for (cmd.handlers.items) |h| {
                if (h.on_destroy) |destroy| {
                    destroy(h.ctx, self.allocator);
                }
            }

            cmd.handlers.deinit(self.allocator);
            self.allocator.free(cmd.name);
            self.allocator.free(cmd.description);
            self.allocator.destroy(cmd);
        }

        self.commands.deinit(self.allocator);
    }

    /// Идемпотентная регистрация. Если команда с таким именем уже есть - возвращаем существующую
    pub fn register(self: *Registry, name: []const u8, description: []const u8) !*Command {
        if (self.commands.get(name)) |existing| {
            return existing;
        }

        const cmd = try self.allocator.create(Command);
        errdefer self.allocator.destroy(cmd);

        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_desc = try self.allocator.dupe(u8, description);
        errdefer self.allocator.free(owned_desc);

        cmd.* = .{
            .name = owned_name,
            .description = owned_desc,
        };

        try self.commands.put(self.allocator, owned_name, cmd);

        return cmd;
    }

    /// Добавить обработчик к команде, при необходимости создав её
    pub fn addHandler(self: *Registry, command_name: []const u8, handler: Handler) !void {
        const cmd = self.commands.get(command_name) orelse try self.register(command_name, "");
        try cmd.handlers.append(self.allocator, handler);
    }

    /// Выполнить команду по имени.
    /// true - команда найдена | false - не найдена.
    /// Ошибки обработчиков пробрасываются.
    pub fn execute(self: *Registry, command_name: []const u8) !bool {
        // FIXME: мне не нравится такая реализация orelse
        const cmd = self.commands.get(command_name) orelse return false;
        try cmd.execute();
        return true;
    }

    pub fn contains(self: *Registry, command_name: []const u8) bool {
        return self.commands.contains(command_name);
    }

    pub fn get(self: *Registry, command_name: []const u8) ?*Command {
        return self.commands.get(command_name);
    }
};

/// Оборачивает типизированный указатель на функцию в Handler.
/// Убирает ручные @ptrCast/@alignCast в месте регистрации.
pub fn makeHandler(comptime Ctx: type, comptime func: *const fn (*Ctx) anyerror!void, ctx: *Ctx) Handler {
    const wrapper = struct {
        fn call(raw: *anyopaque) anyerror!void {
            const typed: *Ctx = @ptrCast(@alignCast(raw));
            return func(typed);
        }
    };

    return .{
        .func = wrapper.call,
        .ctx = @ptrCast(ctx),
    };
}
