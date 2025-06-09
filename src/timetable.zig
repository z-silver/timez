pub const Activity = struct {
    project: []const u8,
    description: []const u8,
};

pub const Session = struct {
    start_time: datetime.DateTime,
    end_time: datetime.DateTime,
    activity: Activity,

    pub fn init(
        start_time: datetime.DateTime,
        end_time: datetime.DateTime,
        description: Activity,
    ) Session {
        return .{
            .start_time = start_time,
            .end_time = end_time,
            .activity = description,
        };
    }
};

pub const Error = error{
    invalid_line,
} || std.mem.Allocator.Error || std.fs.File.Writer.Error;

pub const Out = struct {
    stderr: std.fs.File.Writer,
    line_number: *u32,
};

pub fn fromString(
    gpa: std.mem.Allocator,
    raw_timetable: []const u8,
    out: Out,
) Error![]Session {
    var current_date: ?datetime.Date = null;
    var line_number: u32 = 1;

    defer out.line_number.* = line_number;

    var sessions: std.ArrayListUnmanaged(Session) = .empty;
    errdefer sessions.deinit(gpa);

    // Heuristic: assume lines are 80 bytes long, and every line is an entry.
    try sessions.ensureUnusedCapacity(gpa, @divFloor(raw_timetable.len, 80));

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
            try sessions.append(gpa, session);
            continue :loop .{ .skip = remaining };
        },
        .end => {
            @branchHint(.unlikely);
        },
        .@"error" => |line| {
            @branchHint(.cold);
            try out.stderr.print(
            \\Error: line {} is invalid
            \\While parsing: {s}
            \\Current date: {?}
            \\
            ,
                .{ line_number, line, current_date },
            );
            return error.invalid_line;
        },
    }

    return try sessions.toOwnedSlice(gpa);
}

comptime {
    std.testing.refAllDecls(@This());
}

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");
const assert = std.debug.assert;

const datetime = @import("datetime");

const parse = @import("parse.zig");
