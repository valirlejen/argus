const std = @import("std");
const system_sdk = @import("system_sdk");

const zglfw = @import("zglfw");
const zpool = @import("zpool");

const default_options = struct {
    const uniforms_buffer_size = 4 * 1024 * 1024;
    const dawn_skip_validation = false;
    const buffer_pool_size = 256;
    const texture_pool_size = 256;
    const texture_view_pool_size = 256;
    const sampler_pool_size = 16;
    const render_pipeline_pool_size = 128;
    const compute_pipeline_pool_size = 128;
    const bind_group_pool_size = 32;
    const bind_group_layout_pool_size = 32;
    const pipeline_layout_pool_size = 32;
};

pub const Options = struct {
    uniforms_buffer_size: u64 = default_options.uniforms_buffer_size,
    dawn_skip_validation: bool = default_options.dawn_skip_validation,
    buffer_pool_size: u32 = default_options.buffer_pool_size,
    texture_pool_size: u32 = default_options.texture_pool_size,
    texture_view_pool_size: u32 = default_options.texture_view_pool_size,
    sampler_pool_size: u32 = default_options.sampler_pool_size,
    render_pipeline_pool_size: u32 = default_options.render_pipeline_pool_size,
    compute_pipeline_pool_size: u32 = default_options.compute_pipeline_pool_size,
    bind_group_pool_size: u32 = default_options.bind_group_pool_size,
    bind_group_layout_pool_size: u32 = default_options.bind_group_layout_pool_size,
    pipeline_layout_pool_size: u32 = default_options.pipeline_layout_pool_size,
};

pub const Package = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
    zgpu: *std.Build.Module,
    zgpu_options: *std.Build.Module,
    deps: struct {
        zglfw: zglfw.Package,
        zpool: zpool.Package,
    },

    pub fn link(pkg: Package, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("zgpu", pkg.zgpu);
        exe.root_module.addImport("zgpu_options", pkg.zgpu_options);

        const b = exe.step.owner;

        switch (pkg.target.result.os.tag) {
            .windows => {
                const dawn_dep = b.dependency("dawn_x86_64_windows_gnu", .{});
                exe.root_module.addLibraryPath(.{ .path = dawn_dep.builder.build_root.path.? });
                exe.root_module.addLibraryPath(.{
                    .path = system_sdk.path ++ "/windows/lib/x86_64-windows-gnu",
                });

                exe.root_module.linkSystemLibrary("ole32", .{});
                exe.root_module.linkSystemLibrary("dxguid", .{});
            },
            .linux => {
                if (pkg.target.result.cpu.arch.isX86()) {
                    const dawn_dep = b.dependency("dawn_x86_64_linux_gnu", .{});
                    exe.root_module.addLibraryPath(.{ .path = dawn_dep.builder.build_root.path.? });
                } else {
                    const dawn_dep = b.dependency("dawn_aarch64_linux_gnu", .{});
                    exe.root_module.addLibraryPath(.{ .path = dawn_dep.builder.build_root.path.? });
                }
            },
            .macos => {
                exe.root_module.addFrameworkPath(.{
                    .path = system_sdk.path ++ "/macos12/System/Library/Frameworks",
                });
                exe.root_module.addSystemIncludePath(.{
                    .path = system_sdk.path ++ "/macos12/usr/include",
                });
                exe.root_module.addLibraryPath(.{
                    .path = system_sdk.path ++ "/macos12/usr/lib",
                });

                if (pkg.target.result.cpu.arch.isX86()) {
                    const dawn_dep = b.dependency("dawn_x86_64_macos", .{});
                    exe.root_module.addLibraryPath(.{ .path = dawn_dep.builder.build_root.path.? });
                } else {
                    const dawn_dep = b.dependency("dawn_aarch64_macos", .{});
                    exe.root_module.addLibraryPath(.{ .path = dawn_dep.builder.build_root.path.? });
                }

                exe.root_module.linkSystemLibrary("objc", .{});
                exe.root_module.linkFramework("Metal", .{});
                exe.root_module.linkFramework("CoreGraphics", .{});
                exe.root_module.linkFramework("Foundation", .{});
                exe.root_module.linkFramework("IOKit", .{});
                exe.root_module.linkFramework("IOSurface", .{});
                exe.root_module.linkFramework("QuartzCore", .{});
            },
            else => unreachable,
        }

        exe.root_module.linkSystemLibrary("dawn", .{});
        exe.root_module.link_libc = true;
        exe.root_module.link_libcpp = true;

        exe.root_module.addIncludePath(.{ .path = thisDir() ++ "/libs/dawn/include" });
        exe.root_module.addIncludePath(.{ .path = thisDir() ++ "/src" });

        exe.root_module.addCSourceFile(.{
            .file = .{ .path = thisDir() ++ "/src/dawn.cpp" },
            .flags = &.{ "-std=c++17", "-fno-sanitize=undefined" },
        });
        exe.root_module.addCSourceFile(.{
            .file = .{ .path = thisDir() ++ "/src/dawn_proc.c" },
            .flags = &.{"-fno-sanitize=undefined"},
        });
    }

    pub fn makeTestStep(pkg: Package, b: *std.Build) *std.Build.Step {
        const tests = b.addTest(.{
            .name = "zgpu-tests",
            .root_source_file = .{ .path = thisDir() ++ "/src/zgpu.zig" },
            .target = pkg.target,
            .optimize = pkg.optimize,
        });
        pkg.link(tests);
        pkg.deps.zglfw.link(tests);
        pkg.deps.zpool.link(tests);
        return &b.addRunArtifact(tests).step;
    }
};

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    args: struct {
        options: Options = .{},
        deps: struct {
            zglfw: zglfw.Package,
            zpool: zpool.Package,
        },
    },
) Package {
    const step = b.addOptions();
    step.addOption(u64, "uniforms_buffer_size", args.options.uniforms_buffer_size);
    step.addOption(bool, "dawn_skip_validation", args.options.dawn_skip_validation);
    step.addOption(u32, "buffer_pool_size", args.options.buffer_pool_size);
    step.addOption(u32, "texture_pool_size", args.options.texture_pool_size);
    step.addOption(u32, "texture_view_pool_size", args.options.texture_view_pool_size);
    step.addOption(u32, "sampler_pool_size", args.options.sampler_pool_size);
    step.addOption(u32, "render_pipeline_pool_size", args.options.render_pipeline_pool_size);
    step.addOption(u32, "compute_pipeline_pool_size", args.options.compute_pipeline_pool_size);
    step.addOption(u32, "bind_group_pool_size", args.options.bind_group_pool_size);
    step.addOption(u32, "bind_group_layout_pool_size", args.options.bind_group_layout_pool_size);
    step.addOption(u32, "pipeline_layout_pool_size", args.options.pipeline_layout_pool_size);

    const zgpu_options = step.createModule();

    const zgpu = b.addModule("zgpu", .{
        .root_source_file = .{ .path = thisDir() ++ "/src/zgpu.zig" },
        .imports = &.{
            .{ .name = "zgpu_options", .module = zgpu_options },
            .{ .name = "zglfw", .module = args.deps.zglfw.zglfw },
            .{ .name = "zpool", .module = args.deps.zpool.zpool },
        },
    });

    return .{
        .target = target,
        .optimize = optimize,
        .options = args.options,
        .zgpu = zgpu,
        .zgpu_options = zgpu_options,
        .deps = .{
            .zglfw = args.deps.zglfw,
            .zpool = args.deps.zpool,
        },
    };
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});

    const pkg = package(b, target, optimize, .{
        .options = .{
            .uniforms_buffer_size = b.option(
                u64,
                "uniforms_buffer_size",
                "Set uniforms buffer size",
            ) orelse default_options.uniforms_buffer_size,
            .dawn_skip_validation = b.option(
                bool,
                "dawn_skip_validation",
                "Disable Dawn validation",
            ) orelse default_options.dawn_skip_validation,
            .buffer_pool_size = b.option(
                u32,
                "buffer_pool_size",
                "Set buffer pool size",
            ) orelse default_options.buffer_pool_size,
            .texture_pool_size = b.option(
                u32,
                "texture_pool_size",
                "Set texture pool size",
            ) orelse default_options.texture_pool_size,
            .texture_view_pool_size = b.option(
                u32,
                "texture_view_pool_size",
                "Set texture view pool size",
            ) orelse default_options.texture_view_pool_size,
            .sampler_pool_size = b.option(
                u32,
                "sampler_pool_size",
                "Set sample pool size",
            ) orelse default_options.sampler_pool_size,
            .render_pipeline_pool_size = b.option(
                u32,
                "render_pipeline_pool_size",
                "Set render pipeline pool size",
            ) orelse default_options.render_pipeline_pool_size,
            .compute_pipeline_pool_size = b.option(
                u32,
                "compute_pipeline_pool_size",
                "Set compute pipeline pool size",
            ) orelse default_options.compute_pipeline_pool_size,
            .bind_group_pool_size = b.option(
                u32,
                "bind_group_pool_size",
                "Set bind group pool size",
            ) orelse default_options.bind_group_pool_size,
            .bind_group_layout_pool_size = b.option(
                u32,
                "bind_group_layout_pool_size",
                "Set bind group layout pool size",
            ) orelse default_options.bind_group_layout_pool_size,
            .pipeline_layout_pool_size = b.option(
                u32,
                "pipeline_layout_pool_size",
                "Set pipeline layout pool size",
            ) orelse default_options.pipeline_layout_pool_size,
        },
        .deps = .{
            .zglfw = zglfw_pkg,
            .zpool = zpool_pkg,
        },
    });

    const test_step = b.step("test", "Run zgpu tests");
    test_step.dependOn(pkg.makeTestStep(b));
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
