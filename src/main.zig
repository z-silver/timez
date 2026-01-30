pub fn main() !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_state.deinit();

    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    var stderr_buf: [512]u8 = undefined;
    var stderr_fw = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_fw.interface;

    if (2 < args.len) {
        try stderr.writeAll("Args:");
        for (args[1..]) |arg| {
            try stderr.print(" {s}", .{arg});
        }
        try stderr.writeByte('\n');
        try stderr.flush();
        return error.too_many_arguments;
    }

    const date_format: Date_Format =
        if (args.len == 2 and std.mem.eql(u8, args[1], "--dmy"))
            .dmy
        else
            .international;

    var stdin_buf: [4096]u8 = undefined;
    var stdin_fr = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_fr.interface;

    const raw_timetable: []const u8 =
        try stdin.allocRemaining(arena, .unlimited);

    var stdout_buf: [1024]u8 = undefined;
    var stdout_fw = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_fw.interface;

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
            const minutes = entry.value_ptr.*;
            try print_summary_line(stdout, project, minutes);
            total += minutes.toInt();
        }
        try print_summary_line(stdout, "total", .fromInt(total));
    }
    try stdout.writeByte('\n');

    try stdout.writeAll(
        "project,description,start date,start time,end date,end time,duration\n",
    );
    for (sessions.items) |session| {
        const hours, const minutes = session.duration.toHoursAndMinutes();

        try print_csv_field(stdout, session.activity.project);
        try stdout.writeByte(',');
        try print_csv_field(stdout, session.activity.description);
        try stdout.writeByte(',');
        try print_date(stdout, date_format, session.start_time.date);
        try stdout.print(",{f},", .{
            session.start_time.time,
        });
        try print_date(stdout, date_format, session.end_time.date);
        try stdout.print(",{f},{}:{:02}\n", .{
            session.end_time.time,
            hours,
            minutes,
        });
    }

    try stdout.flush();
}

const Date_Format = enum { international, dmy };

fn print_date(out: *std.Io.Writer, mode: Date_Format, date: datetime.Date) !void {
    try switch (mode) {
        .international => out.print("{f}", .{date}),
        .dmy => out.print("{:02}/{:02}/{}", .{ date.day, date.month.numeric(), date.year }),
    };
}

fn print_summary_line(
    out: *std.Io.Writer,
    project: []const u8,
    duration: timetable.Minutes,
) !void {
    try print_csv_field(out, project);
    const hours, const minutes = duration.toHoursAndMinutes();
    try out.print(",{},{}:{:02}\n", .{
        duration.toInt(),
        hours,
        minutes,
    });
}

fn print_csv_field(out: *std.Io.Writer, subject: []const u8) !void {
    try out.writeByte('"');
    var iter = std.mem.splitScalar(u8, subject, '"');
    try out.writeAll(iter.first());
    while (iter.next()) |after_quote| {
        try out.print("\"\"{s}", .{after_quote});
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
