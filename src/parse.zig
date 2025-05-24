pub fn Parsed(comptime T: type) type {
    return struct { T, []const u8 };
}

pub const Action = union(enum) {
    skip: []const u8,
    date: Parsed(datetime.Date),
    session: Parsed(timetable.Session),
    end: void,
    @"error": []const u8,

    pub fn init(
        current_date: datetime.Date,
        text: []const u8,
    ) Action {
        return if (text.len == 0)
            .end
        else if (session(current_date, text)) |parsed_session|
            .{ .session = parsed_session }
        else if (date_line(text)) |parsed_date|
            .{ .date = parsed_date }
        else if (printable_line(text)) |remaining|
            .{ .skip = remaining }
        else
            .{ .@"error" = line(text).@"0" };
    }

    test init {
        try std.testing.expectEqualDeep(Action{ .skip = "abc" }, Action.init(undefined, "\nabc"));
        try std.testing.expectEqualDeep(Action{ .skip = "abc" }, Action.init(undefined, "whatever I want\nabc"));
        try std.testing.expectEqualDeep(Action{ .@"error" = "\tunprintable" }, Action.init(undefined, "\tunprintable\nabc"));
    }
};

fn digits(text: []const u8) Parsed([]const u8) {
    const char_count = for (text, 0..) |char, position| {
        if (!std.ascii.isDigit(char)) break position;
    } else text.len;
    return .{ text[0..char_count], text[char_count..] };
}

fn uint(comptime Int: type, text: []const u8) ?Int {
    const digit_sequence, _ = digits(text);
    if (digit_sequence.len != text.len) return null;
    return std.fmt.parseInt(Int, digit_sequence, 10) catch null;
}

fn any(count: u32, text: []const u8) ?Parsed([]const u8) {
    return if (count <= text.len)
        .{ text[0..count], text[count..] }
    else
        null;
}

fn whitespace(text: []const u8) []const u8 {
    return std.mem.trimLeft(u8, text, " ");
}

fn activity(text: []const u8) ?Parsed(timetable.Activity) {
    const current_line, const remaining = line(text);
    const empty = printable_line(current_line) orelse return null;
    assert(empty.len == 0);

    var iter = std.mem.splitSequence(u8, current_line, " -- ");

    const project = std.mem.trim(u8, iter.first(), " ");
    if (project.len == 0) return null;

    const description = std.mem.trim(u8, iter.rest(), " ");
    if (description.len == 0) return null;

    return .{
        .{ .project = project, .description = description },
        remaining,
    };
}

test activity {
    try std.testing.expectEqualDeep(
        Parsed(timetable.Activity){ .{
            .project = "timez",
            .description = "adding tests",
        }, "" },
        activity("timez -- adding tests\n"),
    );
}

fn timestamp(
    current_date: datetime.Date,
    text: []const u8,
) ?Parsed(datetime.DateTime) {
    const hour_text, var remaining = any(2, text) orelse return null;
    const hour = uint(u5, hour_text) orelse return null;

    const minute_text, remaining = any(2, remaining) orelse return null;
    const minute = uint(u6, minute_text) orelse return null;

    const at_midnight: datetime.DateTime = .{ .date = current_date };
    return .{
        at_midnight.add(.{ .hours = hour, .minutes = minute }),
        remaining,
    };
}

test timestamp {
    const today: datetime.Date = .init(1999, .aug, 1);

    try std.testing.expectEqualDeep(
        Parsed(datetime.DateTime){ .{
            .date = today,
            .time = .init(23, 32, 0, 0),
        }, "" },
        timestamp(today, "2332"),
    );
    try std.testing.expectEqualDeep(
        Parsed(datetime.DateTime){ .{
            .date = today,
            .time = .init(23, 32, 0, 0),
        }, "-i-dont-care-about-the-remaining-text\n\n" },
        timestamp(today, "2332-i-dont-care-about-the-remaining-text\n\n"),
    );
    try std.testing.expectEqualDeep(
        Parsed(datetime.DateTime){ .{
            .date = today.add(.{ .days = 1 }),
            .time = .init(1, 32, 0, 0),
        }, "" },
        timestamp(today, "2532"),
    );
}

fn session(
    current_date: datetime.Date,
    text: []const u8,
) ?Parsed(timetable.Session) {
    const start_time, var remaining = timestamp(
        current_date,
        text,
    ) orelse return null;

    remaining = literal("-", remaining) orelse return null;

    const end_time, remaining = timestamp(
        current_date,
        remaining,
    ) orelse return null;

    remaining = literal(" ", remaining) orelse return null;

    const parsed_activity, remaining = activity(remaining) orelse return null;

    return .{
        .init(start_time, end_time, parsed_activity),
        remaining,
    };
}

test session {
    const today: datetime.Date = .init(1999, .aug, 1);
    const tomorrow = today.add(.{ .days = 1 });

    const expected: Parsed(timetable.Session) = .{ .init(
        .{ .date = today, .time = .init(23, 32, 0, 0) },
        .{ .date = tomorrow, .time = .init(1, 32, 0, 0) },
        .{
            .project = "timez",
            .description = "adding tests",
        },
    ), "" };

    try std.testing.expectEqualDeep(expected, session(today, "2332-2532 timez -- adding tests\n"));
    try std.testing.expectEqualDeep(expected, session(today, "2332-2532 timez -- adding tests"));
    try std.testing.expectEqualDeep(expected, session(today, "2332-2532     timez    --    adding tests  \n"));
    try std.testing.expectEqualDeep(expected, session(today, "2332-2532     timez    --    adding tests  "));
    try std.testing.expectEqualDeep(null, session(today, " 2332-2532 timez -- adding tests"));
    try std.testing.expectEqualDeep(null, session(today, "2332-2532timez    --    adding tests  \n"));
    try std.testing.expectEqualDeep(null, session(today, "2332-2532 timez--    adding tests  \n"));
    try std.testing.expectEqualDeep(null, session(today, "2332-2532 timez --adding tests  \n"));
}

fn literal(expected: []const u8, text: []const u8) ?[]const u8 {
    return if (std.mem.startsWith(u8, text, expected))
        text[expected.len..]
    else
        null;
}

fn endline(text: []const u8) ?[]const u8 {
    return if (text.len == 0)
        text
    else
        literal("\n", text) orelse literal("\r\n", text);
}

fn printable_line(text: []const u8) ?[]const u8 {
    return endline(text) orelse
        if (std.ascii.isPrint(text[0]))
            @call(.always_tail, printable_line, .{text[1..]})
        else
            null;
}

fn date(text: []const u8) ?Parsed(datetime.Date) {
    if (text.len < 10) return null;
    return .{
        datetime.Date.parseRfc3339(text[0..10]) catch return null,
        text[10..],
    };
}

fn date_line(text: []const u8) ?Parsed(datetime.Date) {
    const parsed_date, const remaining = date(text) orelse return null;
    if (endline(remaining)) |after_endline| {
        return .{ parsed_date, after_endline };
    }
    const after_space = literal(" ", remaining) orelse return null;
    if (endline(after_space)) |_| return null;
    if (std.ascii.isWhitespace(after_space[0])) return null;

    const after_printable = printable_line(remaining) orelse return null;
    return .{ parsed_date, after_printable };
}

fn line(text: []const u8) Parsed([]const u8) {
    var iter = std.mem.splitScalar(u8, text, '\n');
    const prefix = iter.first();
    const remaining = iter.rest();
    return .{
        prefix[0 .. prefix.len - @intFromBool(
            std.mem.endsWith(u8, prefix, "\r"),
        )],
        remaining,
    };
}

comptime {
    std.testing.refAllDecls(@This());
}

test {
    std.testing.refAllDecls(@This());
}

const timetable = @import("timetable.zig");
const datetime = @import("datetime");
const std = @import("std");
const assert = std.debug.assert;
