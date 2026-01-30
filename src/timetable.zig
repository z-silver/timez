pub const Activity = struct {
    project: []const u8,
    description: []const u8,
};

pub const Session = struct {
    start_time: datetime.DateTime,
    end_time: datetime.DateTime,
    activity: Activity,
    duration: Minutes,

    pub fn init(
        start_time: datetime.DateTime,
        end_time: datetime.DateTime,
        description: Activity,
    ) Session {
        const start = start_time.toEpoch();
        const end = end_time.toEpoch();

        const duration = @divFloor(
            end - start,
            datetime.Time.subseconds_per_min,
        );

        return .{
            .start_time = start_time,
            .end_time = end_time,
            .activity = description,
            .duration = .fromInt(duration),
        };
    }
};

pub const ParseError = error{
    invalid_line,
} || std.mem.Allocator.Error || std.Io.Writer.Error;

pub const SessionList = std.ArrayListUnmanaged(Session);

pub fn fromString(
    gpa: std.mem.Allocator,
    raw_timetable: []const u8,
    out: struct {
        stderr: *std.Io.Writer,
        line_number: *u32,
    },
) ParseError!SessionList {
    var current_date: ?datetime.Date = null;
    var line_number: u32 = 1;
    defer out.line_number.* = line_number;

    var sessions: SessionList = .empty;
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
                \\Current date: {?f}
                \\
            ,
                .{ line_number, line, current_date },
            );
            try out.stderr.flush();
            return error.invalid_line;
        },
    }

    return sessions;
}

pub const Minutes = enum(i64) {
    _,
    pub fn fromInt(int: i64) Minutes {
        return @enumFromInt(int);
    }
    pub fn toInt(self: Minutes) i64 {
        return @intFromEnum(self);
    }
    pub fn toHoursAndMinutes(self: Minutes) struct { i64, u6 } {
        const duration = self.toInt();
        const odd_hours = @divFloor(duration, 60);
        const odd_minutes: u6 = @intCast(@mod(duration, 60));
        return .{
            odd_hours + @intFromBool(odd_hours < 0 and 0 != odd_minutes),
            if (0 <= odd_hours or odd_minutes == 0)
                odd_minutes
            else
                60 - odd_minutes,
        };
    }
};

pub const Summary = std.StringHashMapUnmanaged(Minutes);

pub fn summary(
    gpa: std.mem.Allocator,
    sessions: []const Session,
) std.mem.Allocator.Error!Summary {
    var subtotals: Summary = .empty;
    errdefer subtotals.deinit(gpa);

    // Heuristic: I don't usually work on a lot of different things.
    try subtotals.ensureUnusedCapacity(gpa, 12);

    for (sessions) |session| {
        const key = session.activity.project;
        const previous_total: Minutes = subtotals.get(key) orelse .fromInt(0);

        try subtotals.put(gpa, key, .fromInt(
            previous_total.toInt() + session.duration.toInt(),
        ));
    }

    return subtotals;
}

comptime {
    std.testing.refAllDecls(@This());
}

test {
    std.testing.refAllDecls(@This());
}

const std = @import("std");
const datetime = @import("datetime");
const parse = @import("parse.zig");
