pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    var stderr_buf: [512]u8 = undefined;
    var stderr_fw = std.Io.File.stderr().writer(io, &stderr_buf);
    const stderr = &stderr_fw.interface;

    if (1 < args.len) {
        try stderr.writeAll("Args:");
        for (args[1..]) |arg| {
            try stderr.print(" {s}", .{arg});
        }
        try stderr.writeByte('\n');
        try stderr.flush();
        return error.too_many_arguments;
    }

    var stdin_buf: [4096]u8 = undefined;
    var stdin_fr = std.Io.File.stdin().reader(io, &stdin_buf);
    const stdin = &stdin_fr.interface;

    const raw_timetable: []const u8 =
        try stdin.allocRemaining(arena, .unlimited);

    var stdout_buf: [1024]u8 = undefined;
    var stdout_fw = std.Io.File.stdout().writer(io, &stdout_buf);
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
        const sign, const hours, const minutes = session.duration.toHoursAndMinutes();

        try print_csv_field(stdout, session.activity.project);
        try stdout.writeByte(',');
        try print_csv_field(stdout, session.activity.description);
        try stdout.print(",{f},{f},{f},{f},{s}{}:{:02}\n", .{
            session.start_time.date,
            session.start_time.time,
            session.end_time.date,
            session.end_time.time,
            sign,
            hours,
            minutes,
        });
    }

    try stdout.flush();
}

fn print_summary_line(
    out: *std.Io.Writer,
    project: []const u8,
    duration: timetable.Minutes,
) !void {
    try print_csv_field(out, project);
    const sign, const hours, const minutes = duration.toHoursAndMinutes();
    try out.print(",{},{s}{}:{:02}\n", .{
        duration.toInt(),
        sign,
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
