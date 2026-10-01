const std = @import("std");
const fs = @import("../platform/fs.zig");

pub const TYPE_NAME = "project-tree";

pub const NodeKind = enum { file, directory };

pub const Node = struct {
    name: []const u8,
    path: []const u8,
    kind: NodeKind,
    parent: ?*Node = null,
    children: std.ArrayListUnmanaged(*Node) = .empty,
    loaded: bool = false,
    expanded: bool = false,
};

pub const VisibleEntry = struct {
    node: *Node,
    depth: usize,
};

pub const ProjectTree = struct {
    pub const TYPE_NAME = "project-tree";   // ← вот здесь

    gpa: std.mem.Allocator,
    io: std.Io,
    arena: std.heap.ArenaAllocator,
    root: *Node,

    selected: usize = 0,
    scroll: usize = 0,

    visible: std.ArrayListUnmanaged(VisibleEntry) = .empty,
    dirty: bool = true,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, root_path: []const u8) !*ProjectTree {
        const self = try gpa.create(ProjectTree);
        errdefer gpa.destroy(self);

        self.* = .{
            .gpa = gpa,
            .io = io,
            .arena = std.heap.ArenaAllocator.init(gpa),
            .root = undefined,
        };

        const a = self.arena.allocator();
        const norm_path = std.mem.trimEnd(u8, root_path, "/");
        const name = std.fs.path.basename(if (norm_path.len == 0) "/" else norm_path);

        self.root = try a.create(Node);
        self.root.* = .{
            .name = try a.dupe(u8, name),
            .path = try a.dupe(u8, if (norm_path.len == 0) "/" else norm_path),
            .kind = .directory,
        };

        try self.loadChildren(self.root);
        self.root.expanded = true;

        return self;
    }

    pub fn deinit(self: *ProjectTree) void {
        const gpa = self.gpa;
        self.visible.deinit(gpa);
        self.arena.deinit();
        gpa.destroy(self);
    }

    /// Универсальный destroy_fn для Buffer.
    pub fn destroy(state: *anyopaque, allocator: std.mem.Allocator) void {
        _ = allocator;
        const self: *ProjectTree = @ptrCast(@alignCast(state));
        self.deinit();
    }

    pub fn refresh(self: *ProjectTree) !void {
        _ = self.arena.reset(.retain_capacity);

        const a = self.arena.allocator();
        const old_path = self.root.path;
        const old_name = self.root.name;

        self.root = try a.create(Node);
        self.root.* = .{
            .name = try a.dupe(u8, old_name),
            .path = try a.dupe(u8, old_path),
            .kind = .directory,
        };

        try self.loadChildren(self.root);
        self.root.expanded = true;

        self.selected = 0;
        self.scroll = 0;
        self.dirty = true;
    }

    pub fn selectedNode(self: *ProjectTree) ?*Node {
        const vis = self.getVisible() catch return null;
        if (self.selected >= vis.len) return null;
        return vis[self.selected].node;
    }

    pub fn getVisible(self: *ProjectTree) ![]const VisibleEntry {
        if (self.dirty) try self.rebuildVisible();
        return self.visible.items;
    }

    pub fn moveUp(self: *ProjectTree) void {
        if (self.selected > 0) self.selected -= 1;
    }

    pub fn moveDown(self: *ProjectTree) void {
        const vis = self.getVisible() catch return;
        if (self.selected + 1 < vis.len) self.selected += 1;
    }

    pub fn toggle(self: *ProjectTree) !void {
        const vis = try self.getVisible();
        if (self.selected >= vis.len) return;

        const node = vis[self.selected].node;
        if (node.kind != .directory) return;

        const anchor = node;

        if (node.expanded) {
            node.expanded = false;
        } else {
            if (!node.loaded) try self.loadChildren(node);
            node.expanded = true;
        }

        self.dirty = true;
        try self.reselect(anchor);
    }

    pub fn enter(self: *ProjectTree) !void {
        const vis = try self.getVisible();
        if (self.selected >= vis.len) return;

        const node = vis[self.selected].node;
        if (node.kind == .directory) {
            try self.toggle();
        } else {
            std.log.info("[project-tree] open file: {s}", .{node.path});
        }
    }

    pub fn adjustScroll(self: *ProjectTree, viewport_height: usize) void {
        if (viewport_height == 0) return;
        if (self.selected < self.scroll) {
            self.scroll = self.selected;
        } else if (self.selected >= self.scroll + viewport_height) {
            self.scroll = self.selected - viewport_height + 1;
        }
    }

    // --- internal ---

    fn loadChildren(self: *ProjectTree, node: *Node) !void {
        if (node.loaded) return;
        if (node.kind != .directory) return;

        const a = self.arena.allocator();

        var entries = fs.listDirectory(self.gpa, self.io, node.path) catch |err| {
            std.log.warn("[project-tree] cannot read {s}: {}", .{ node.path, err });
            node.loaded = true;
            return;
        };
        defer {
            for (entries.items) |e| self.gpa.free(e.name);
            entries.deinit(self.gpa);
        }

        for (entries.items) |entry| {
            const child = try a.create(Node);
            const child_path = try std.fs.path.join(a, &.{ node.path, entry.name });
            child.* = .{
                .name = try a.dupe(u8, entry.name),
                .path = child_path,
                .kind = if (entry.is_dir) .directory else .file,
                .parent = node,
            };
            try node.children.append(a, child);
        }

        std.mem.sort(*Node, node.children.items, {}, nodeLessThan);
        node.loaded = true;
    }

    fn nodeLessThan(_: void, a: *Node, b: *Node) bool {
        if (a.kind == .directory and b.kind == .file) return true;
        if (a.kind == .file and b.kind == .directory) return false;
        return std.mem.lessThan(u8, a.name, b.name);
    }

    fn rebuildVisible(self: *ProjectTree) !void {
        self.visible.clearRetainingCapacity();
        try self.walk(self.root, 0);
        self.dirty = false;
    }

    fn walk(self: *ProjectTree, node: *Node, depth: usize) !void {
        try self.visible.append(self.gpa, .{ .node = node, .depth = depth });
        if (node.kind == .directory and node.expanded) {
            for (node.children.items) |child| {
                try self.walk(child, depth + 1);
            }
        }
    }

    fn reselect(self: *ProjectTree, anchor: *Node) !void {
        _ = try self.getVisible();
        for (self.visible.items, 0..) |entry, i| {
            if (entry.node == anchor) {
                self.selected = i;
                return;
            }
        }
    }
};
