//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

pub fn main() !void {
    // const stdin_file = std.io.getStdIn().reader();
    // var br = std.io.bufferedReader(stdin_file);
    // const stdin = br.reader();
    // var line: [1024]u8 = undefined;
    const test_string = "1999-08-01";

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const digits, _ = parse.date(test_string) orelse return error.invalid_date;

    try stdout.print("Digits: {}.\n", .{digits});

    try bw.flush(); // Don't forget to flush!
}

const parse = @import("parse.zig");
const Year = std.time.epoch.Year;
const YearLeapKind = std.time.epoch.YearLeapKind;
const Month = std.time.epoch.Month;
const MonthAndDay = std.time.epoch.MonthAndDay;
const assert = std.testing.assert;
const std = @import("std");
