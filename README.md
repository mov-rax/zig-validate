# Zig-Validate

### A type validation library for writing a zero-cost, declarative, understandable, generic code in zig.

---

For many projects, the desired method of creating generic types is to do either of the following:

1. Use a concrete type that results in code bloat due to repetitiveness.
2. Use a concrete type that uses composition and hand-rolled vtables to emulate interfaces from other languages and incurring a runtime cost.
3. Use an `anytype` and have the caller of the function hope that sufficient documentation was written or comb through the codebase to see what methods are required.
4. Hand-roll type validation for a specific type every time a generic type is required.
5. Use a switch to hand-roll static dispatch in zig due to lack of function overloading.

*If only there was a way to have traits or interfaces in zig without having to waste time in repetitively writing error-prone imperative code for type validation...*

### Oh wait, __now there is!__

__Zig-Validate__ provides a non-obtrusive solution to all of those problems with a simple-to-use interface and a rich error reporting solution for relaying to the user issues with non-conforming generic types.

All that is required to use in order to harness the power of compile-time type varification is a single function: `ValidateWith`.

The following is an example that shows the simplicity in using this library:

```zig
pub fn validate = @import("validate");
/// Generic Iterable Validator
pub fn Iterable(comptime Target: type) type {
    return struct {
        pub const next = (fn (*@This()) Target.Output);
        pub fn printNext(self: *Target) void {
            std.log.info("{}", .{self.next()});
        }
    };
}

/// Function that validates `iter`'s type against Iterable
pub fn genericFunction(iter: anytype) void {
    const IterType = @TypeOf(iter);
    const Iter = validate.ValidateWith(IterType, Iterable(IterType));
    const a = Iter.Target.next(&iter) * 2;
    std.log.info("{}", .{a});
    Iter.Validator.printNext(&a);
}
```
### Now, for an explanation:
In the above code, `Iterable` defines everything that is needed to verify any generic type. 

The `Target.Output` means that it requires the `Target` to have a public declaration named `Output` whose value is a type.

Requirements for functions that must be implemented by the generic type are defined as `const functionName = functionType`. Due to zig limitations on namespacing and in order to avoid name collisions, the definition and implementation are separated in the output type's `Validator` and `Target` declarations respectively.

Default implementations can be defined in the  `Validator` just like any other `struct` in zig. However, due to the lack of overloading and namespacing limitations, they **must not be implemented** by the `Target`.

The `Validator` **can not have any fields**, as the `Target` cannot also access those fields due to limitations in zig's metaprogramming abilities. Thus, **the `Validator` can only contain declarations.**

### So, how do we create a type that will be validated?

The following showcases the implementation of a type that conforms to the requirements of the `Iterable` validator above:

```zig
pub const Iterablei32 = struct{
    pub const Output = i32;
    current: Output,

    pub fn next(self: *@This()) Output {
        self.current += 1;
        return current;
    }
};
```
`Iterablei32` contains the implementation of the requirements defined in the `Iterable` validator.

It contains both the public declaration named `Output` that is required by `Target.Output` in the validator, and the `next` function defined by `next` requirement.

### But what if I want to validate against multiple validators?

If multiple validators want to be used, simply combine them all into a single validator using all of their namespaces.

Example:
```zig
const Validator = struct{
    pub usingnamespace Validator1;
    pub usingnamespace Validator2;
    pub usingnamespace Validator3;
};
const V = ValidateWith(Target, Validator);
```

### What if I have an existing application/library that would require too much refactoring to use the output type?

If you have a codebase that would require a large amount of refactoring to use the output type, then you can simply _not_ use the output type. Due to the unobtrusive nature of *zig-validate*, you can simply do `_ = validateWith(Target, Validator)` and still use the type validation power of the library. The only downside of discarding the output type is a generic trait/interface that is used to interact with generic `Target` types.

That's pretty much all that there is needed to know in order to use **zig-validate**! Now, stop writing boilerplate and bear witness to the power of **zig-validate**.

Still unsure on how to use **zig-validate**? Then [Read zig-validate's documentation!](https://mov-rax.github.io/zig-validate/)