const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "lumicode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const zsdl = b.dependency("zsdl", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zsdl2", zsdl.module("zsdl2"));
    exe.root_module.addImport("zsdl2_ttf", zsdl.module("zsdl2_ttf"));

    exe.root_module.link_libc = true;
    linkSdlLibs(exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run lumicode");
    run_step.dependOn(&run_cmd.step);
}

fn linkSdlLibs(compile: *std.Build.Step.Compile) void {
    switch (compile.rootModuleTarget().os.tag) {
        .windows => {
            compile.root_module.linkSystemLibrary("SDL2", .{});
            compile.root_module.linkSystemLibrary("SDL2main", .{});
            compile.root_module.linkSystemLibrary("SDL2_ttf", .{});
        },
        .linux => {
            compile.root_module.linkSystemLibrary("SDL2", .{});
            compile.root_module.linkSystemLibrary("SDL2_ttf", .{});
        },
        .macos => {
            compile.root_module.linkFramework("SDL2", .{});
            compile.root_module.linkFramework("SDL2_ttf", .{});
        },
        else => {},
    }
}
