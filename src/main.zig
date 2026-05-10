const std = @import("std");

const extension_icons = std.StaticStringMap([]const u8).initComptime(.{
    .{ ".zig", "\x1b[38;5;214m\u{e8ef}" },
    .{ ".rs", "\x1b[38;5;244m\u{e7a8}" },
    .{ ".go", "\x1b[38;5;12m\u{f07d3}" },
    .{ ".ts", "\x1b[38;5;12m\u{e628}" },
    .{ ".js", "\x1b[38;5;226m\u{e60c}" },
    .{ ".json", "\x1b[38;5;226m\u{e60b}" },
    .{ ".wasm", "\x1b[38;5;99m\u{e6a1}" },
    .{ ".c", "\x1b[38;5;75m\u{e649}" },
    .{ ".h", "\x1b[38;5;171m\u{e649}" },
    .{ ".cpp", "\x1b[38;5;75m\u{f0672}" },
    .{ ".cppm", "\x1b[38;5;75m\u{f0672}" },
    .{ ".hpp", "\x1b[38;5;171m\u{f0672}" },
    .{ ".html", "\x1b[38;5;208m\u{e60e}" },
    .{ ".md", "\x1b[38;5;32m\u{e609}" },
    .{ ".vim", "\x1b[38;5;34m\u{e7c5}" },
    .{ ".py", "\x1b[38;5;31m\u{e73c}" },
    .{ ".toml", "\x1b[38;5;130m\u{e6b2}" },
    .{ ".swift", "\x1b[38;5;203m\u{e699}" },
    .{ ".lua", "\x1b[38;5;27m\u{e620}" },

    .{ ".sh", "\x1b[38;5;154m\u{e691}" },
    .{ ".zsh", "\x1b[38;5;154m\u{e691}" },
    .{ ".bat", "\x1b[38;5;12m\u{e70f}" },
    .{ ".cmd", "\x1b[38;5;12m\u{e70f}" },

    .{ ".png", "\x1b[38;5;135m\u{f03e}" },
    .{ ".jpg", "\x1b[38;5;135m\u{f03e}" },
    .{ ".svg", "\x1b[38;5;135m\u{e698}" },
});

const special_icons = std.StaticStringMap([]const u8).initComptime(.{
    .{ ".gitignore", "\x1b[38;5;67m\u{e702}" },
    .{ ".gitattributes", "\x1b[38;5;67m\u{e702}" },
    .{ ".zshrc", "\x1b[38;5;154m\u{e691}" },
    .{ ".npmignore", "\x1b[38;5;196m\u{e616}" },
    .{ "tsconfig.json", "\x1b[38;5;12m\u{e8ca}" },
    .{ "CMakeLists.txt", "\x1b[38;5;154m\u{e794}" },
    .{ "go.mod", "\x1b[38;5;12m\u{f07d3}" },
    .{ ".vimrc", "\x1b[38;5;34m\u{e7c5}" },
    .{ "COPYING", "\x1b[38;5;226m\u{e60a}" },
    .{ "LICENSE", "\x1b[38;5;226m\u{e60a}" },
});

const special_dir_icons = std.StaticStringMap([]const u8).initComptime(.{
    .{ ".git", "\u{e5fb}" },
});

fn getExtensionIcon(extension: []const u8) []const u8 {
    if (extension_icons.get(extension)) |icon| return icon;
    return "\u{e64e}";
}

fn getIcon(path: []const u8) []const u8 {
    if (special_icons.get(path)) |icon| return icon;
    return getExtensionIcon(std.fs.path.extension(path));
}

fn getDirIcon(path: []const u8) []const u8 {
    if (special_dir_icons.get(path)) |icon| return icon;
    return "\u{e5ff}";
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();

    const path: []const u8 = if (args.next()) |arg|
        arg
    else
        ".";
    var dir = std.Io.Dir.cwd().openDir(init.io, path, .{ .iterate = true }) catch |err| {
        if (err == error.NotDir) {
            try writer.print("{s}\n", .{path});
        } else try writer.print("ls: {s}: No such file or directory\n", .{path});
        return;
    };
    defer dir.close(init.io);

    const DirEntry = struct {
        kind: std.Io.File.Kind,
        name: []const u8,
    };

    var iter = dir.iterate();
    var entries: std.ArrayList(DirEntry) = .empty;
    while (try iter.next(init.io)) |entry| {
        if (entry.kind != .directory and entry.kind != .file) continue;
        try entries.append(allocator, .{
            .kind = entry.kind,
            .name = try allocator.dupe(u8, entry.name),
        });
    }

    std.mem.sort(
        DirEntry,
        entries.items,
        {},
        struct {
            fn lessThan(_: void, lhs: DirEntry, rhs: DirEntry) bool {
                if (lhs.kind == rhs.kind)
                    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
                return @intFromEnum(lhs.kind) < @intFromEnum(rhs.kind);
            }
        }.lessThan,
    );

    var largest_entry_length: usize = 0;

    for (entries.items, 0..) |entry, i| {
        if (i % 2 != 0) continue;
        if (entry.name.len > largest_entry_length) largest_entry_length = entry.name.len;
    }

    for (entries.items, 0..) |entry, i| {
        try writer.print(
            " {s} \x1b[0m \x1b[{s}m{s}\x1b[0m",
            .{
                if (entry.kind == .directory) getDirIcon(entry.name) else getIcon(entry.name),
                if (entry.kind == .directory) "1;36" else "0",
                entry.name,
            },
        );
        if (i % 2 == 0) {
            for (0..(largest_entry_length - entry.name.len)) |_| {
                try writer.writeByte(' ');
            }
            try writer.writeAll("  ");
        } else {
            try writer.writeByte('\n');
        }
    }
    try writer.writeByte('\n');
}
