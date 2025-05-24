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

const datetime = @import("datetime");
const std = @import("std");
const assert = std.debug.assert;
