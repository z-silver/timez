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

    var current_date: datetime.Date = .now();
    var line_number: u32 = 1;
    loop: switch (parse.Action.init(current_date, raw_timetable)) {
        .skip => |remaining| {
            line_number += 1;
            continue :loop .init(
                current_date,
                remaining,
            );
        },
        .date => |parsed_date| {
            @branchHint(.unlikely);
            current_date, const remaining = parsed_date;
            continue :loop .{ .skip = remaining };
        },
        .session => |parsed_session| {
            const session, const remaining = parsed_session;
            _ = session; // autofix
            // TODO
            continue :loop .{ .skip = remaining };
        },
        .end => {
            @branchHint(.unlikely);
        },
        .@"error" => |line| {
            @branchHint(.cold);
            try stderr.print(
                "Error: line {} is invalid\nWhile parsing: {s}\n",
                .{ line_number, line },
            );
            return error.invalid_line;
        },
    }

    try bw.flush();
}

test {
    _ = parse;
}

const std = @import("std");
const assert = std.debug.assert;

const datetime = @import("datetime");

const parse = @import("parse.zig");
