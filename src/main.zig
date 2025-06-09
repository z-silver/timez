pub fn main() !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const arena = arena_state.allocator();

    const raw_timetable: []const u8 = try std.io.getStdIn().readToEndAlloc(
        arena,
        std.math.maxInt(u32),
    );

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    _ = stdout; // autofix

    const stderr = std.io.getStdErr().writer();

    var line_number: u32 = 0;

    const sessions = try timetable.fromString(
        arena,
        raw_timetable,
        .{ .stderr = stderr, .line_number = &line_number },
    );
    _ = sessions; // autofix

    try bw.flush();
}

test {
    _ = parse;
    _ = timetable;
}

const std = @import("std");
const assert = std.debug.assert;

const datetime = @import("datetime");

const parse = @import("parse.zig");
const timetable = @import("timetable.zig");
