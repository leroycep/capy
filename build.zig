const std = @import("std");

pub const pkg = std.build.Pkg{
    .name = "capy",
    .source = std.build.FileSource{ .path = thisDir() ++ "/src/main.zig" },
    .dependencies = &.{zigimg},
};

const zigimg = std.build.Pkg{
    .name = "zigimg",
    .source = std.build.FileSource{ .path = @import("root").dependencies.build_root.zigimg ++ "/zigimg.zig" },
};

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("capy", null);
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.linkLibC();
    lib.install();

    switch (lib.target.getOsTag()) {
        .windows => {
            switch (lib.build_mode) {
                .Debug => lib.subsystem = .Console,
                else => lib.subsystem = .Windows,
            }
            lib.linkSystemLibrary("comctl32");
            lib.linkSystemLibrary("gdi32");
            lib.linkSystemLibrary("gdiplus");
            switch (lib.target.toTarget().cpu.arch) {
                .x86_64 => lib.addObjectFile("src/backends/win32/res/x86_64.o"),
                //.i386 => lib.addObjectFile(prefix ++ "/src/backends/win32/res/i386.o"), // currently disabled due to problems with safe SEH
                else => {}, // not much of a problem as it'll just lack styling
            }
        },
        .macos => {
            if (@import("builtin").os.tag != .macos) {
                const sdk_root_dir = b.pathFromRoot("macos-sdk/");
                const sdk_framework_dir = std.fs.path.join(b.allocator, &.{ sdk_root_dir, "System/Library/Frameworks" }) catch unreachable;
                const sdk_include_dir = std.fs.path.join(b.allocator, &.{ sdk_root_dir, "usr/include" }) catch unreachable;
                const sdk_lib_dir = std.fs.path.join(b.allocator, &.{ sdk_root_dir, "usr/lib" }) catch unreachable;
                lib.addFrameworkPath(sdk_framework_dir);
                lib.addSystemIncludePath(sdk_include_dir);
                lib.addLibraryPath(sdk_lib_dir);
            }

            lib.linkLibC();
            lib.linkFramework("CoreData");
            lib.linkFramework("ApplicationServices");
            lib.linkFramework("CoreFoundation");
            lib.linkFramework("Foundation");
            lib.linkFramework("AppKit");
            lib.linkSystemLibraryName("objc");
        },
        .linux, .freebsd => {
            lib.linkLibC();
            lib.linkSystemLibrary("gtk+-3.0");
        },
        .freestanding => {
            if (lib.target.toTarget().isWasm()) {
                // Things like the image reader require more stack than given by default
                // TODO: remove once ziglang/zig#12589 is merged
                lib.stack_size = std.math.max(lib.stack_size orelse 0, 256 * 1024);
                if (lib.build_mode == .ReleaseSmall) {
                    lib.strip = true;
                }
            } else {
                return error.UnsupportedOs;
            }
        },
        else => {
            // TODO: use the GLES backend as long as the windowing system is supported
            // but the UI library isn't
            return error.UnsupportedOs;
        },
    }
}

pub fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file).? ++ std.fs.path.sep_str;
}
