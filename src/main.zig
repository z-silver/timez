pub fn main() !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_state.deinit();

    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    const stderr = std.io.getStdErr().writer();

    if (2 < args.len) {
        try stderr.print("Args: {string}\n", .{args});
        return error.too_many_arguments;
    }

    const date_format: Date_Format =
        if (args.len == 2 and std.mem.eql(u8, args[1], "--dmy"))
            .dmy
        else
            .international;

    const raw_timetable: []const u8 = try std.io.getStdIn().readToEndAlloc(
        arena,
        std.math.maxInt(u32),
    );

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

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

        try print_csv_field(stdout, session.activity.project);
        try stdout.writeByte(',');
        try print_csv_field(stdout, session.activity.description);
        try stdout.writeByte(',');
        try print_date(stdout, date_format, session.start_time.date);
        try stdout.print(",{rfc3339},", .{
            session.start_time.time,
        });
        try print_date(stdout, date_format, session.end_time.date);
        try stdout.print(",{rfc3339},{}:{:02}\n", .{
            session.end_time.time,
            hours,
            minutes,
        });
    }

    try bw.flush();
}

const Date_Format = enum { international, dmy };

fn print_date(out: anytype, mode: Date_Format, date: datetime.Date) !void {
    try switch (mode) {
        .international => out.print("{rfc3339}", .{date}),
        .dmy => out.print("{:02}/{:02}/{}", .{ date.day, date.month.numeric(), date.year }),
    };
}

fn print_summary_line(
    out: anytype,
    project: []const u8,
    minutes: i64,
) !void {
    try print_csv_field(out, project);
    try out.print(",{},{}:{:02}\n", .{
        minutes,
        @divFloor(minutes, 60),
        @as(u6, @intCast(@mod(minutes, 60))),
    });
}

fn print_csv_field(out: anytype, subject: []const u8) !void {
    try out.writeByte('"');
    var iter = std.mem.splitScalar(u8, subject, '"');
    try out.writeAll(iter.first());
    while (iter.next()) |after_quote| {
        try out.print("\"\"{string}", .{after_quote});
    }
    try out.writeByte('"');
}

test {
    _ = parse;
    _ = timetable;
}

const std = @import("std");
const datetime = @import("datetime");
const parse = @import("parse.zig");
const timetable = @import("timetable.zig");
