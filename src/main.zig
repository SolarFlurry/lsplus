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
    .{ "COPYING", "\x1b[38;5;226m\u{e60a}" },
    .{ "LICENSE", "\x1b[38;5;226m\u{e60a}" },
});

fn getExtensionIcon(extension: []const u8) []const u8 {
    if (extension_icons.get(extension)) |icon| return icon;
    return "\u{e64e}";
}

fn getIcon(path: []const u8) []const u8 {
    if (special_icons.get(path)) |icon| return icon;
    return getExtensionIcon(std.fs.path.extension(path));
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var buffer: [1024]u8 = undefined;
    var stdout = std.fs.File.stdout();
    var output_stream = stdout.writer(&buffer).interface;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();
    const path: []const u8 = if (args.next()) |arg|
        arg
    else
        ".";
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
        try output_stream.print("Could not open {s}\n", .{path});
        try output_stream.flush();
        std.process.exit(1);
    };
    defer dir.close();

    var largest_entry_length: usize = 0;

    var iter = dir.iterate();
    var entries: std.ArrayList(std.fs.Dir.Entry) = .empty;
    while (try iter.next()) |entry| {
        if (entry.kind != .directory and entry.kind != .file) continue;
        try entries.append(allocator, .{
            .kind = entry.kind,
            .name = try allocator.dupe(u8, entry.name),
        });
        if (entry.name.len > largest_entry_length) largest_entry_length = entry.name.len;
    }

    std.mem.sort(
        std.fs.Dir.Entry,
        entries.items,
        {},
        struct {
            fn lessThan(_: void, lhs: std.fs.Dir.Entry, rhs: std.fs.Dir.Entry) bool {
                if (lhs.kind == rhs.kind)
                    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
                return @intFromEnum(lhs.kind) < @intFromEnum(rhs.kind);
            }
        }.lessThan,
    );

    for (entries.items, 0..) |entry, i| {
        try output_stream.print(
            " {s} \x1b[0m \x1b[{s}m{s}\x1b[0m",
            .{
                if (entry.kind == .directory) "\u{f07c}" else getIcon(entry.name),
                if (entry.kind == .directory) "1;36" else "0",
                entry.name,
            },
        );
        if (i % 2 == 0) {
            for (0..(largest_entry_length - entry.name.len)) |_| {
                try output_stream.writeByte(' ');
            }
            try output_stream.writeAll("  ");
        } else {
            try output_stream.writeByte('\n');
        }
    }
    try output_stream.writeByte('\n');

    try output_stream.flush();
}
