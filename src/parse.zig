pub fn Parsed(comptime T: type) type {
    return struct { T, []const u8 };
}

fn digits(text: []const u8) Parsed([]const u8) {
    const char_count = for (text, 0..) |char, position| {
        if (!std.ascii.isDigit(char)) break position;
    } else text.len;
    return .{ text[0..char_count], text[char_count..] };
}

fn int(comptime Int: type, text: []const u8) ?Parsed(Int) {
    const digit_sequence, const remaining = digits(text);
    if (digit_sequence.len == 0) return null;
    return .{
        std.fmt.parseInt(Int, digit_sequence, 10) catch return null,
        remaining,
    };
}

fn dash(text: []const u8) ?[]const u8 {
    if (text.len == 0) return null;
    return if (text[0] == '-') text[1..] else null;
}

pub fn date(text: []const u8) ?Parsed(Date) {
    const year, var remaining = int(Year, text) orelse return null;
    remaining = dash(remaining) orelse return null;

    const month, remaining = int(u4, remaining) orelse return null;
    if (month == 0 or 12 < month) return null;
    remaining = dash(remaining) orelse return null;

    const day, remaining = int(u5, remaining) orelse return null;
    if (day == 0) return null;
    const parsed_date = Date.init(
        year,
        @enumFromInt(month),
        .init(day),
    ) orelse return null;

    return .{ parsed_date, remaining };
}

test date {
    const actual, _ = date("1999-08-01") orelse unreachable;
    try std.testing.expectEqual(Date.init(1999, .aug, .init(1)), actual);
}

const std = @import("std");
const Date = @import("Date.zig");
const Year = std.time.epoch.Year;
const YearLeapKind = std.time.epoch.YearLeapKind;
const Month = std.time.epoch.Month;
const MonthAndDay = std.time.epoch.MonthAndDay;
const assert = std.debug.assert;
