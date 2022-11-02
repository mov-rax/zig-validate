# Static Dispatch

__Zig-Validate__'s main feature is its ability to perform static dispatch in regards to validating types. There is no runtime cost incurred from static dispatch.

There are two distinct methods of static dispatch that are present in __zig-validate__: One with function overloading, and one without.

__Zig-Validate__ leverages `Validators` for validating types and performing static dispatch. A `Validator` is a `struct` that contains only declarations. Each declaration must be assigned either function type that a `Target` type must contain during compile time or a function definition.

Example:
```zig
const Validator = struct{
    const functionA = fn(*@This()) @This();
    const functionB = fn(*@This()) i64;
    pub fn magical() void {
        std.log.info("hello from magical()", .{});
    }
};
```
In the above validator definition, the `Target` type must implement `functionA` and `functionB` with the given type signatures. `magical` already had a definition so it must not be implemented in the `Target` type (no function overriding).

Another thing to note is the `@This()` builtin being used in the validator. When the `Target` type is being validated, the `@This()` is interpreted as being the `Target` rather than the `Validator` (within const declarations). This allows for concrete types to be more useful in validation purposes.

Another version of writing generic validators is by using a function like so:
```zig
pub fn Validator(comptime T: type) type {
    return struct{
        const functionA = fn(*T) T;
        const functionB = fn(*T, i32) i32;
        pub fn magical(self: *T) void {
            std.log.info("hello from magical()", .{});
            std.log.info("functionB: {}", .{self.functionB(9)});
        }    
    };
}
```
This version of writing validators is preferred whenever function definitions in a `Validator` need to call a method in a `Target`.

### Combining multiple Validators

If multiple validators want to be used, simply combine them all into a single validator using all of their namespaces.

Example:
```zig
const Validator = struct{
    pub usingnamespace Validator1;
    pub usingnamespace Validator2;
    pub usingnamespace Validator3;
};
const V = validate.static(Target, Validator);
```

---

## Non-function overloading

To use static dispatch without function overloading, the function to use is `validate.static`.It takes in types `Target` and `Validator`.

`validate.static` returns a struct containing `Target` and `Validator` namespaces that contain only declarations. The `Target` contains declarations that are present in the `Target`, while `Validator` contains declarations that are present in the `Validator`. The reason for the separation are name collisions that would occur if the namespaces were merged (note that this is taken care of if function overloading is desired).

Also take note that using the return value from `validate.static` is not a requirement for type validation and can be discarded.

The following is an example of using `validate.static`:

```zig
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

/// A generic sumIter without the need to pass in the type.
/// It uses `Deref` function from utils to find out the type of the pointee.
fn sumIter(iterRef: anytype, target: i32) i32 {
    const T = Deref(@TypeOf(iterRef));
    const Iter = validate.static(T, Iterable(T));
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
```

The above outlines using a data structure that conforms to the `Iterable` Validator.

If the above code was in a library, then the definition of `IterableInt` would be all that the user of the library would need to implement.

The `validate.utils.Deref` function extracts the base type from a pointer type. I.E. `Deref(*T)` or `Deref(**T)` returns `T`.

---

## Function overloading

__Zig-Validate__ also provides a version of validation that supports function overloading. This usually results in shorter, more readable code than its non-overloading variant.

Below is an example showcasing function overloading using `validate.staticFnOverride`.

```zig
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

    const iface = validate.staticFnOverride(Inline.Human, Inline.Animal(Inline.Human));
    var hooman = Inline.Human{ .name = "Bob", .age = 21 };
    try std.testing.expectEqualStrings(iface.getName(&hooman), "Bob");
    try std.testing.expectEqual(iface.getAge(&hooman), 21);
    try std.testing.expectEqualStrings(iface.getStructName(), "Human");
    try std.testing.expectEqualStrings(iface.family(), "Animalia");
}
```

`validate.staticFnOverride` returns an instance of an anonymous struct populated with comptime fields. This creates a comptime interface that statically dispatches function calls. Being that all of the fields are marked as `comptime`, none of them end up in the final binary, resulting in a static dispatch abstraction with no runtime cost.

`validate.staticFnOverride` takes in a `Target` and a `Validator` similarly to `validate.static`. However, it allows for implementations in `Validator` to be overridden in `Target`. (Currently, it allows for overriding even with different function definitions, which will be fixed in a later update).

> For more examples on static dispatch and type validation in _zig-validate_ view [validateTests.zig](https://github.com/mov-rax/zig-validate/blob/main/src/validateTests.zig)
