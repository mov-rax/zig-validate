# Dynamic Dispatch

This was an area of contention, as users can already create a version of dynamic dispatch while utilizing static dispatch by using tagged unions. However, implementing and using such a version of dynamic dispatch was quite involved and laden with boilerplace, so this version of dynamic dispatch using generated vtables was created instead.

The following is an example of dynamic dispatch using `validate.utils.vtableify`:

```zig
test "Dynamic Dispatch" {
    const Inline = struct{
        const Animal = struct{
            name: *const fn(*const @This()) []const u8,
            speak: *const fn() void,
            age: *const fn(*const @This()) usize,
            species: *const fn() []const u8,

            pub fn oof(self: *const @This()) void {
                std.log.warn("Name: {s}", .{self.name(self)});
                std.log.warn("Age: {}", .{self.age(self)});
                std.log.warn("Species: {s}", .{self.species()});
                self.speak();
            }
        };

        const Human = struct{
            animal: Animal = validate.utils.vtableify(Animal, AnimalImpl),
            age: usize,
            name: []const u8,
            
            const AnimalImpl = struct{
                pub fn name(self: *const Animal) []const u8 {
                    return @fieldParentPtr(Human, "animal", self).name;
                }
                pub fn speak() void {
                    std.log.warn("I think I'm blind...", .{});
                }
                pub fn age(self: *const Animal) usize {
                    return @fieldParentPtr(Human, "animal", self).age;
                }
                pub fn species() []const u8 {
                    return "Human";
                }
            };
        };

        const Dog = struct{
            animal: Animal = validate.utils.vtableify(Animal, AnimalImpl),
            age: usize,
            name: []const u8,
            
            const AnimalImpl = struct{
                pub fn name(self: *const Animal) []const u8 {
                    return @fieldParentPtr(Dog, "animal", self).name;
                }
                pub fn speak() void {
                    std.log.warn("Woof!", .{});
                }
                pub fn age(self: *const Animal) usize {
                    return @fieldParentPtr(Dog, "animal", self).age;
                }
                pub fn species() []const u8 {
                    return "Dog";
                }
            };
        };

        fn testy(item: *const Animal) void {
            std.log.info("Animal name: {s}", .{item.name(item)});
            std.log.info("Animal age: {}", .{item.age(item)});
            item.speak();
        }
    };
    var dogg = Inline.Dog{.age = 4, .name = "Woofer"};
    var hooman = Inline.Human{ .age = 42, .name = "John Doe" };
    var animals = [2]*Inline.Animal{ &dogg.animal, &hooman.animal };
    for (animals) |animal| {
        animal.oof();
        Inline.testy(animal);
    }
}
```

> Note that the implementation of the vtable does not have to be separate, and can be inlined.

> Autogeneration of wrapper functions are to be added in a later update.

The above shows an `Animal` vtable that both `Human` and `Dog` implement. Any `Animal` can access fields within its parent struct using `@fieldParentPtr`. 

`vtableify` turns a struct filled with function definitions into a vtable with fields that point to those definitions.

It is preferrable to use static dispatch using `ValidateWith` or `validateWithMerged` instead of `vtableify` whenever speed and safety is preferred (as the types are validated to work at runtime), where `vtableify` (currently) does not.