const validate = @import("validate.zig");
const std = @import("std");
const Deref = @import("utils.zig").Deref;

pub fn Iterable(comptime T: type) type {
    return struct {
        pub const next = (fn (*@This()) T.Output);
        pub const peek = (fn (*@This()) T.Output);
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

    pub fn peek(self: *@This()) i32 {
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

test "Generic Validator Merged" {
    const Iter = validate.validateWithMerged(IterableInt, Iterable(IterableInt));
    var iter = IterableInt{ .current = 0 };
    try std.testing.expect(Iter.next(&iter) == 1);
    Iter.printNext(&iter);
}

/// sum iterator until it reaches the target value.
fn sumIterT(comptime T: type, iter: *T, target: i32) i32 {
    const Iter = validate.ValidateWith(T, Iterable(T));
    var sum: i32 = 0;
    var curr: i32 = Iter.Target.next(iter);
    while (curr < target) : (curr = Iter.Target.next(iter)) {
        sum += curr;
    }
    return sum;
}

test "sumIterT example" {
    var iter = IterableInt{ .current = 10 };
    const result = sumIterT(IterableInt, &iter, 36);
    try std.testing.expectEqual(result, 575);
}

/// A generic sumIter without the need to pass in the type.
/// It uses `Deref` function from utils to find out the type of the pointee.
fn sumIter(iterRef: anytype, target: i32) i32 {
    const T = Deref(@TypeOf(iterRef));
    const Iter = validate.ValidateWith(T, Iterable(T));
    var sum: i32 = 0;
    var curr: i32 = Iter.Target.next(iterRef);
    while (curr < target) : (curr = Iter.Target.next(iterRef)) {
        sum += curr;
    }
    return sum;
}

test "sumIter example" {
    var iter = IterableInt{ .current = 10 };
    const result = sumIter(&iter, 36);
    try std.testing.expectEqual(result, 575);
}

/// A more generic SumIter function. Should be within `Iterable` but is its own function for reference.
/// It uses `Deref` function from utils to find out the type of the pointee.
fn genericSumIter(iterRef: anytype, target: Deref(@TypeOf(iterRef)).Output) Deref(@TypeOf(iterRef)).Output {
    const Type = Deref(@TypeOf(iterRef));
    const Iter = validate.ValidateWith(Type, Iterable(Type));
    var sum: Type.Output = 0;
    var curr: Type.Output = Iter.Target.next(iterRef);
    while (curr < target) : (curr = Iter.Target.next(iterRef)) {
        sum += curr;
    }
    return sum;
}

fn genericSumIterMerged(iterRef: anytype, target: Deref(@TypeOf(iterRef)).Output) Deref(@TypeOf(iterRef)).Output {
    const Type = Deref(@TypeOf(iterRef));
    const iter = validate.validateWithMerged(Type, Iterable(Type));
    var sum: Type.Output = 0;
    var curr: Type.Output = iter.next(iterRef);
    while (curr < target) : (curr = iter.next(iterRef)) {
        sum += curr;
    }
    return sum;
}

test "genericSumIter example" {
    var iter = IterableInt{ .current = 10 };
    const result = genericSumIter(&iter, 36);
    try std.testing.expectEqual(result, 575);
}

test "genericSumIterMerged example" {
    var iter = IterableInt{ .current = 10 };
    const result = genericSumIterMerged(&iter, 36);
    try std.testing.expectEqual(result, 575);
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

test "Concrete Validator Merged" {
    const iface = validate.validateWithMerged(ConcreteIterableInt, ConcreteIterable);
    var iter = ConcreteIterableInt{ .current = 1 };
    try std.testing.expect(iface.next(&iter) == 2);
    try std.testing.expect(iface.concrete(&iter) == 4);
    try std.testing.expect(iface.validator() == 21);
}

fn Addable(comptime T: type) type {
    return struct {
        pub const add = fn (T, T) T;
    };
}

const Addablei32 = packed struct {
    val: i32,
    pub fn add(self: @This(), other: @This()) @This() {
        return .{ .val = self.val + other.val };
    }
};

test "other" {
    const a = Addablei32{ .val = 3 };
    const Add = validate.ValidateWith(Addablei32, Addable(Addablei32));
    _ = Add.Target.add(a, Addablei32{ .val = 4 });
}

test "Example Validation" {
    const Inline = struct {
        pub fn ExampleValidator(comptime T: type) type {
            return struct {
                const magic = (fn (T, i32, i64, f32) f32);
                const wonder = (fn ([]const u8, []const usize) usize);
            };
        }

        pub const ExampleTarget = struct {
            value: i32,
            pub fn magic(self: @This(), a: i32, b: i64, c: f32) f32 {
                _ = a;
                _ = b;
                return c + 1.0 + @intToFloat(f32, self.value);
            }
            pub fn wonder(first: []const u8, second: []const usize) usize {
                return first.len + second.len;
            }
        };

        /// Example function that takes a type conforming to `ExampleValidator`
        pub fn example(val: anytype) void {
            const Ex = validate.ValidateWith(@TypeOf(val), ExampleValidator(@TypeOf(val)));
            _ = Ex.Target.magic(val, 3, 4, 2.2);
            _ = Ex.Target.wonder("Farquad", &[_]usize{ 4, 10, 13 });
        }
    };

    var target = Inline.ExampleTarget{ .value = 4 };
    Inline.example(target);
}

test "Inline Validator" {
    const Inline = struct {
        pub const ExampleTarget = struct {
            val: i32,

            pub fn succ(self: @This()) @This() {
                return .{ .val = self.val + 1 };
            }
            pub fn value(self: @This()) i32 {
                return self.val;
            }
        };
        /// Example function that takes a type conforming to an inline validator.
        pub fn example(val: anytype) void {
            const Ex = validate.ValidateWith(@TypeOf(val), struct {
                pub const succ = (fn (@This()) @This());
                pub const value = (fn (@This()) i32);
            });

            _ = Ex.Target.succ(val);
            _ = Ex.Target.value(val);
        }
    };
    var target = Inline.ExampleTarget{ .val = 1 };
    Inline.example(target);
}

test "Function Overloading" {
    const Inline = struct {
        pub fn Animal(comptime T: type) type {
            return struct {
                const getName = fn (*@This()) []const u8;
                const getAge = fn (*T) usize;

                // override
                pub fn getStructName() []const u8 {
                    return "Animal";
                }

                pub fn family() []const u8 {
                    return "Animalia";
                }
                // override
                pub fn speak() []const u8 {
                    return "???";
                }
            };
        }

        pub const Human = struct {
            name: []const u8,
            age: usize,
            pub fn getName(self: *@This()) []const u8 {
                return self.name;
            }
            pub fn getStructName() []const u8 {
                return "Human";
            }
            pub fn getAge(self: *@This()) usize {
                return self.age;
            }
            pub fn speak() []const u8 {
                return "Hello";
            }
        };
    };

    const iface = validate.validateWithMerged(Inline.Human, Inline.Animal(Inline.Human));
    var hooman = Inline.Human{ .name = "Bob", .age = 21 };
    try std.testing.expectEqualStrings(iface.getName(&hooman), "Bob");
    try std.testing.expectEqual(iface.getAge(&hooman), 21);
    try std.testing.expectEqualStrings(iface.getStructName(), "Human");
    try std.testing.expectEqualStrings(iface.family(), "Animalia");
}
