const std = @import("std");
pub const types = @import("types.zig");
pub const colors = @import("colors.zig");

/// Derefrences a Pointer type until it reaches its base non-pointer value type.
/// Example: `Deref(**i32) == i32`.
pub fn Deref(comptime Type: type) type {
    return switch (@typeInfo(Type)) {
        .Pointer => |v| Deref(v.child),
        else => Type,
    };
}

/// Extracts declarations from a type and outputs a slice of `types.TypeStruct` that
/// contain both the name of the declaration and its `std.builtin.Type` information.
pub fn extract(comptime T: type, comptime isValidator: bool) []const types.TypeStruct {
    var decls = std.meta.declarations(T);
    var declNames: []const u8 = "";

    inline for (decls) |d| {
        if (d.is_pub) {
            declNames = d.name ++ " " ++ declNames;
        }
    }

    var iter = std.mem.tokenize(u8, declNames, " ");
    var result: []const types.TypeStruct = &.{};
    while (iter.next()) |i| {
        result = result ++ &[_]types.TypeStruct{.{
            .name = i,
            .info = if (isValidator) blk: { // if the decl is a type, add it, otherwise continue.
                if (@TypeOf(@field(T, i)) == type) {
                    break :blk @typeInfo(@field(T, i));
                } else continue;
            } else @typeInfo(if (@TypeOf(@field(T, i)) == type) @field(T, i) else @TypeOf(@field(T, i))),
        }};
    }
    return result;
}

/// Enumerates the amount of indirection of a given type.
/// Ex. pointerDepth(**i32) == 2
pub fn pointerDepth(comptime Type: type) i32 {
    return switch (@typeInfo(Type)) {
        .Pointer => |v| 1 + pointerDepth(v.child),
        else => 0,
    };
}

/// Generates a function error message from a given requirement `req` and a slice of the types that are erroneous.
/// Valid types in the function definition are `null` in `errArgsTypes`, while invalid ones hold the expected type.
pub fn genFunctionStr(comptime req: types.TypeStruct, comptime errArgsTypes: []const ?type) ?[]const u8 {
    comptime {
        const redu = colors.redi;
        const red = colors.red;
        const greenu = colors.validatori;
        const yellowu = colors.targeti;
        const bold = colors.normal;

        const ErrPos = struct { left: usize, right: usize };
        const args: []const std.builtin.Type.Fn.Param = req.info.Fn.args;
        const numberOfDescLines = blk: { // get number of lines needed to display a description of erroneous types.
            var cnt: usize = 0;
            for (errArgsTypes) |p| {
                cnt += if (p) |_| 1 else 0;
            }
            break :blk cnt;
        };

        { // check that there is actually an error.
            var hasType = false;
            for (errArgsTypes) |err| {
                if (err) |_| {
                    hasType = true;
                }
            }
            if (!hasType)
                return null;
        }

        // -1 because of return type param
        if ((errArgsTypes.len - 1) != args.len)
            @compileError(std.fmt.comptimePrint("length mismatch between requirements and position of erroneous types. `{}` vs `{}`", .{ args.len, errArgsTypes.len }));

        var result: []const u8 = bold("fn " ++ req.name ++ "(");

        var visualLength = result.len - bold("").len; // because invisible ansi codes are used, this variable is used to keep track of positions.
        var errpos: [errArgsTypes.len]ErrPos = undefined; // saves data on the position of erroneous types.
        var descLines: [numberOfDescLines][]const u8 = undefined; // holds the lines used fore describing errors

        // build function definition string with erroneous types colored red.
        {
            var i: usize = 0;
            var descLineCounter: usize = 0;
            while (i < errArgsTypes.len) : (i += 1) {
                var typeName = blk: {
                    if (i < args.len) {
                        break :blk if (args[i].is_generic) "anytype" else @typeName(args[i].arg_type.?);
                    } else {
                        break :blk @typeName(req.info.Fn.return_type.?);
                    }
                };
                if (i == args.len) {
                    result = result ++ bold(") ");
                    visualLength += 2;
                }
                if (errArgsTypes[i]) |t| { // argument type is erroneous
                    // set line error description.
                    descLines[descLineCounter] = std.fmt.comptimePrint(redu("expected type ") ++ greenu("`{s}`") ++ redu(", found ") ++ yellowu("`{s}`"), .{ @typeName(t), typeName });
                    descLineCounter += 1;
                    // calculate arrow location and span.
                    errpos[i].left = visualLength;
                    visualLength += typeName.len;
                    result = result ++ redu(typeName);
                    errpos[i].right = errpos[i].left + typeName.len;
                } else {
                    visualLength += typeName.len;
                    result = result ++ bold(typeName);
                }
                if (i < args.len - 1) { // print , if not the last arg
                    visualLength += 2;
                    result = result ++ bold(", ");
                }
                if (i == errArgsTypes.len - 1) { // append newline character to end of function definition
                    result = result ++ "\n";
                }
            }
        }
        // Arrows
        {
            var lastRight: usize = 0;
            for (errArgsTypes) |isErroneus, i| {
                if (isErroneus) |_| {
                    var errArrows = red("^" ** (errpos[i].right - errpos[i].left));
                    result = result ++ (" " ** (errpos[i].left - lastRight)) ++ errArrows;
                    lastRight = errpos[i].right;
                }
            }
            result = result ++ "\n";
        }
        // Pipes and descriptive error lines.
        {
            var i: isize = 0; // start at first erroneous type.
            var j: isize = @intCast(isize, numberOfDescLines - 1); // start at topmost descriptive error line.
            while (j >= 0) {
                var lastLeft: usize = 0;
                var counter: usize = 0;
                while (i < errArgsTypes.len) : (i += 1) {
                    if (errArgsTypes[i]) |_| {
                        // position information of erroneous type.
                        const pos = errpos[i];
                        // calculation of number of spaces between pipes/descriptions.
                        const spaceWidth = if (counter == 0) pos.left else (pos.left - lastLeft - 1);
                        if (counter == j) { // location of descriptive error line is reached.
                            result = result ++ red((" " ** spaceWidth) ++ descLines[j]) ++ "\n";
                            j -= 1; // move to another description
                            break;
                        } else {
                            counter += 1;
                            result = result ++ red((" " ** spaceWidth) ++ "|");
                            lastLeft = pos.left;
                        }
                    }
                }
                i = 0;
                counter = 0;
            }
        }

        return result;
    }
}

/// Checks to see if a target conforms to a validator requirement.
/// If it does not, it will return a slice of `types.AssertError` which contains
/// every requirement that the `Target` does not conform to.
pub fn assertIsConforming(comptime Validator: types.ValidationStruct, comptime Target: types.ValidationStruct, comptime ValidatorReq: types.TypeStruct, comptime TargetReqs: []const types.TypeStruct) []const types.AssertError {
    const validator = colors.validator;
    const target = colors.target;
    const normal = colors.normal;
    var isMissing = true;
    var errors: []const types.AssertError = &.{};
    for (TargetReqs) |t| {
        // check if name of validator function and target function are the same.
        if (!std.mem.eql(u8, ValidatorReq.name, t.name)) continue;
        isMissing = false;
        // assert that they actually are both functions
        if (t.info != .Fn) {
            errors = errors ++ &[_]types.AssertError{.{ .desc = std.fmt.comptimePrint(target("`{s}`") ++ normal(" in ") ++ target("`{s}`") ++ normal(" is not a function"), .{ t.name, Target.name }) }};
        }
        if (ValidatorReq.info != .Fn) {
            errors = errors ++ &[_]types.AssertError{.{ .desc = std.fmt.comptimePrint(target("`{s}`") ++ normal(" in ") ++ target("`{s}`") ++ normal(" is not a function"), .{ ValidatorReq.name, Validator.name }) }};
        }
        if (!((t.info == .Fn) and (ValidatorReq.info == .Fn))) continue; // cannot continue executing below code if either one of them are not functions.
        // check that the number of parameters are the same.
        if (t.info.Fn.args.len != ValidatorReq.info.Fn.args.len) {
            errors = errors ++ &[_]types.AssertError{.{ .desc = std.fmt.comptimePrint(normal("Expected parameter length ") ++ validator("{},") ++ normal(" found ") ++ target("{}"), .{
                ValidatorReq.info.Fn.args.len,
                t.info.Fn.args.len,
            }) }};
            continue; // cannot continue executing code below if number of args differ.
        }

        // Figure out which types are erroneous.
        var errTypes: [t.info.Fn.args.len + 1]?type = undefined;
        for (t.info.Fn.args ++ &[_]std.builtin.Type.Fn.Param{.{ .is_generic = false, .is_noalias = false, .arg_type = t.info.Fn.return_type }}) |param, i| {
            const vargs = ValidatorReq.info.Fn.args ++ &[_]std.builtin.Type.Fn.Param{.{ .is_generic = false, .is_noalias = false, .arg_type = ValidatorReq.info.Fn.return_type }};
            // anytype as a parameter
            if (vargs[i].is_generic and param.is_generic) {
                errTypes[i] = null;
                continue;
            }
            // @This() or *@This() as a parameter
            if ((Deref(param.arg_type.?) == Target.type) and (Deref(vargs[i].arg_type.?) == Validator.type) and (pointerDepth(param.arg_type.?) == pointerDepth(vargs[i].arg_type.?))) {
                errTypes[i] = null;
                continue;
            }
            // general checking if type is the same.
            if (vargs[i].arg_type.? != param.arg_type.?) {
                errTypes[i] = vargs[i].arg_type;
            } else {
                errTypes[i] = null;
                continue;
            }
        }
        //const returnTypeErr: ?type = if (t.info.Fn.return_type.? != ValidatorReq.info.Fn.return_type.?) ValidatorReq.info.Fn.return_type else null;
        if (genFunctionStr(t, &errTypes)) |str| {
            errors = errors ++ &[_]types.AssertError{.{ .desc = str }};
        }
    }
    if (isMissing) {
        errors = errors ++ &[_]types.AssertError{.{ .desc = std.fmt.comptimePrint(normal("expected function ") ++ validator("`{s}`") ++ normal(" with type ") ++ validator("`{any}`"), .{ ValidatorReq.name, @Type(ValidatorReq.info) }) }};
    }
    return errors;
}
