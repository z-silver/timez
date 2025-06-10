pub fn main() !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_state.deinit();

    const arena = arena_state.allocator();

    const raw_timetable: []const u8 = try std.io.getStdIn().readToEndAlloc(
        arena,
        std.math.maxInt(u32),
    );

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const stderr = std.io.getStdErr().writer();

    var line_number: u32 = 0;

    const sessions = try timetable.fromString(
        arena,
        raw_timetable,
        .{ .stderr = stderr, .line_number = &line_number },
    );

    const summary = try timetable.summary(arena, sessions.items);
    {
        try stdout.writeAll(
            "project,total duration (minutes),total duration (hours)\n",
        );

        var total: i64 = 0;
        var summary_iter = summary.iterator();
        while (summary_iter.next()) |entry| {
            const project = entry.key_ptr.*;
            const minutes = entry.value_ptr.toInt();
            try print_summary_line(stdout, project, minutes);
            total += minutes;
        }
        try print_summary_line(stdout, "total", total);
    }
    try stdout.writeByte('\n');

    try stdout.writeAll(
        "project,description,start date,start time,end date,end time,duration\n",
    );
    for (sessions.items) |session| {
        const duration = session.duration.toInt();
        const odd_hours = @divFloor(duration, 60);
        const odd_minutes: u6 = @intCast(@mod(duration, 60));
        const hours = odd_hours + @intFromBool(odd_hours < 0 and 0 != odd_minutes);
        const minutes = if (0 <= odd_hours or odd_minutes == 0)
            odd_minutes
        else
            60 - odd_minutes;

        try stdout.print("{string},{string},{rfc3339},{rfc3339},{rfc3339},{rfc3339},{}:{:02}\n", .{
            session.activity.project,
            session.activity.description,
            session.start_time.date,
            session.start_time.time,
            session.end_time.date,
            session.end_time.time,
            hours,
            minutes,
        });
    }

    try bw.flush();
}

fn print_summary_line(
    out: anytype,
    project: []const u8,
    minutes: i64,
) !void {
    try out.print("{string},{},{}:{:02}\n", .{
        project,
        minutes,
        @divFloor(minutes, 60),
        @as(u6, @intCast(@mod(minutes, 60))),
    });
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
