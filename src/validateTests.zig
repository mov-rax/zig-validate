const validate = @import("validate.zig");
const std = @import("std");

pub fn Iterable(comptime T: type) type {
    return struct {
        pub const next = (fn (*@This()) T.Output);
        pub fn printNext(self: *T) void {
            std.log.warn("{}", .{self.next()});
        }
    };
}

const IterableInt = struct {
    const Output = i32;
    current: i32 = 0,

    pub fn next(self: *@This()) i32 {
        self.current += 1;
        return self.current;
    }

    pub fn run(self: *@This()) void {
        std.log.warn("RUNNING {}", .{self.current});
    }
};

test "Generic Validator" {
    const Iter = validate.ValidateWith(IterableInt, Iterable(IterableInt));
    var iter = IterableInt{ .current = 0 };
    try std.testing.expect(Iter.Target.next(&iter) == 1);
    Iter.Validator.printNext(&iter);
}

const ConcreteIterableInt = struct {
    current: i32,

    pub fn next(self: *@This()) i32 {
        self.current += 1;
        return self.current;
    }

    pub fn concrete(self: *@This()) i32 {
        return self.current * 2;
    }
};

const ConcreteIterable = struct {
    const next = (fn (*@This()) i32);
    pub fn validator() i32 {
        return 21;
    }
};

test "Concrete Validator" {
    const Iter = validate.ValidateWith(ConcreteIterableInt, ConcreteIterable);
    var iter = ConcreteIterableInt{ .current = 1 };
    try std.testing.expect(Iter.Target.next(&iter) == 2);
    try std.testing.expect(Iter.Target.concrete(&iter) == 4);
    try std.testing.expect(Iter.Validator.validator() == 21);
}
