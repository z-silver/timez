year: Year,
month: Month,
day: Day,

pub const Year = epoch.Year;
pub const Month = epoch.Month;

pub const Day = enum(u5) {
    invalid = 0,
    _,

    pub fn init(day: u5) ?Day {
        return if (day == 0) null else @enumFromInt(day);
    }

    pub fn to_int(self: Day) u5 {
        assert(self != .invalid);
        return @intFromEnum(self);
    }
};

pub fn init(year: Year, month: Month, day: Day) ?Date {
    const days_in_month = epoch.getDaysInMonth(
        if (epoch.isLeapYear(year)) .leap else .not_leap,
        month,
    );
    if (days_in_month < @intFromEnum(day)) return null;
    return .{ .year = year, .month = month, .day = day };
}

const Date = @This();
const std = @import("std");
const assert = std.testing.assert;
const epoch = std.time.epoch;
