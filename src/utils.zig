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
pub fn extract(comptime T: type, comptime info: enum { validator, target, vtable }) []const types.TypeStruct {

    // extraction of fields is a straightforward mapping of StructField to types.TypeStruct
    if (info == .vtable) {
        var fields = std.meta.fields(T);
        var result: []const types.TypeStruct = &.{};
        inline for (fields) |f| {
            if (@typeInfo(f.type) != .Pointer) {
                @compileError("VTable fields are only allowed to be `*const` function pointers.");
            }
            result = result ++ &[_]types.TypeStruct{.{
                .name = f.name,
                .info = @typeInfo(Deref(f.type)), // deref so that it works with assertIsConforming
            }};
        }
        return result;
    }

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
            .info = if (info == .validator) blk: { // if the decl is a type, add it, otherwise continue.
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
/// Valid types in the function definition are `null` in `errParamsTypes`, while invalid ones hold the expected type.
pub fn genFunctionStr(comptime req: types.TypeStruct, comptime errParamsTypes: []const ?type) ?[]const u8 {
    comptime {
        const redu = colors.redi;
        const red = colors.red;
        const greenu = colors.validatori;
        const yellowu = colors.targeti;
        const bold = colors.normal;

        const ErrPos = struct { left: usize, right: usize };
        const params: []const std.builtin.Type.Fn.Param = req.info.Fn.params;
        const numberOfDescLines = blk: { // get number of lines needed to display a description of erroneous types.
            var cnt: usize = 0;
            for (errParamsTypes) |p| {
                cnt += if (p) |_| 1 else 0;
            }
            break :blk cnt;
        };

        { // check that there is actually an error.
            var hasType = false;
            for (errParamsTypes) |err| {
                if (err) |_| {
                    hasType = true;
                }
            }
            if (!hasType)
                return null;
        }

        // -1 because of return type param
        if ((errParamsTypes.len - 1) != params.len)
            @compileError(std.fmt.comptimePrint("length mismatch between requirements and position of erroneous types. `{}` vs `{}`", .{ params.len, errParamsTypes.len }));

        var result: []const u8 = bold("fn " ++ req.name ++ "(");

        var visualLength = result.len - bold("").len; // because invisible ansi codes are used, this variable is used to keep track of positions.
        var errpos: [errParamsTypes.len]ErrPos = undefined; // saves data on the position of erroneous types.
        var descLines: [numberOfDescLines][]const u8 = undefined; // holds the lines used fore describing errors

        // build function definition string with erroneous types colored red.
        {
            var i: usize = 0;
            var descLineCounter: usize = 0;
            while (i < errParamsTypes.len) : (i += 1) {
                var typeName = blk: {
                    if (i < params.len) {
                        break :blk if (params[i].is_generic) "anytype" else @typeName(params[i].type.?);
                    } else {
                        break :blk @typeName(req.info.Fn.return_type.?);
                    }
                };
                if (i == params.len) {
                    result = result ++ bold(") ");
                    visualLength += 2;
                }
                if (errParamsTypes[i]) |t| { // argument type is erroneous
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
                if (i < params.len - 1) { // print , if not the last arg
                    visualLength += 2;
                    result = result ++ bold(", ");
                }
                if (i == errParamsTypes.len - 1) { // append newline character to end of function definition
                    result = result ++ "\n";
                }
            }
        }
        // Arrows
        {
            var lastRight: usize = 0;
            for (errParamsTypes, 0..) |isErroneus, i| {
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
                while (i < errParamsTypes.len) : (i += 1) {
                    if (errParamsTypes[i]) |_| {
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
        if (t.info.Fn.params.len != ValidatorReq.info.Fn.params.len) {
            errors = errors ++ &[_]types.AssertError{.{ .desc = std.fmt.comptimePrint(normal("Expected parameter length ") ++ validator("{},") ++ normal(" found ") ++ target("{}"), .{
                ValidatorReq.info.Fn.params.len,
                t.info.Fn.params.len,
            }) }};
            continue; // cannot continue executing code below if number of params differ.
        }

        // Figure out which types are erroneous.
        var errTypes: [t.info.Fn.params.len + 1]?type = undefined;
        for (t.info.Fn.params ++ &[_]std.builtin.Type.Fn.Param{.{ .is_generic = false, .is_noalias = false, .type = t.info.Fn.return_type }}, 0..) |param, i| {
            const vparams = ValidatorReq.info.Fn.params ++ &[_]std.builtin.Type.Fn.Param{.{ .is_generic = false, .is_noalias = false, .type = ValidatorReq.info.Fn.return_type }};
            // anytype as a parameter
            if (vparams[i].is_generic and param.is_generic) {
                errTypes[i] = null;
                continue;
            }
            // @This() or *@This() as a parameter
            if ((Deref(param.type.?) == Target.type) and (Deref(vparams[i].type.?) == Validator.type) and (pointerDepth(param.type.?) == pointerDepth(vparams[i].type.?))) {
                errTypes[i] = null;
                continue;
            }
            // general checking if type is the same.
            if (vparams[i].type.? != param.type.?) {
                errTypes[i] = vparams[i].type;
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

pub fn VTableType(comptime T: type) type {
    const decls = comptime std.meta.declarations(T);
    var things: []const std.builtin.Type.StructField = &.{};
    for (decls) |decl| {
        const ftype = @TypeOf(&@field(T, decl.name));
        things = things ++ &[_]std.builtin.Type.StructField{.{ .name = decl.name, .type = ftype, .default_value = null, .is_comptime = false, .alignment = @alignOf(ftype) }};
    }
    return @Type(.{ .Struct = .{ .layout = .Auto, .fields = things, .decls = &.{}, .is_tuple = false } });
}

/// Creates a vtable used for dynamic dispatch.
pub fn vtableify(comptime VTable: type, comptime Implementation: type) VTable {
    const Type = VTableType(Implementation);
    const fields = @typeInfo(Type).Struct.fields;
    var result: VTable = undefined;
    inline for (fields) |f| {
        @field(result, f.name) = &@field(Implementation, f.name);
    }
    return result;
}

/// Merges two structs together. Declarations become comptime fields. Fields disappear.
/// NOTE: References to @This() remain unchanged.
pub fn StructMerge(comptime T: type, comptime R: type) type {
    const StructField = std.builtin.Type.StructField;
    const Declaration = std.builtin.Type.Declaration;
    // const Tfields: []const StructField = @typeInfo(T).Struct.fields;
    // const Rfields: []const StructField = @typeInfo(R).Struct.fields;
    const Tdecls = std.meta.declarations(T);
    const Rdecls = std.meta.declarations(R);

    const MergeDecl = struct {
        name: []const u8,
        parent_type: type,
        is_pub: bool,

        pub fn from(comptime decl: Declaration, comptime Parent: type) @This() {
            return .{
                .name = decl.name,
                .parent_type = Parent,
                .is_pub = decl.is_pub,
            };
        }
    };

    var decls: []const MergeDecl = &.{};
    //var fields: []const StructField = &.{};

    outerloop: for (Tdecls) |td| {
        for (Rdecls) |rd| {
            if (std.mem.eql(u8, td.name, rd.name) or !td.is_pub) {
                continue :outerloop;
            }
        }
        decls = decls ++ &[_]MergeDecl{MergeDecl.from(td, T)};
    }
    for (Rdecls) |rd| {
        if (rd.is_pub)
            decls = decls ++ &[_]MergeDecl{MergeDecl.from(rd, R)};
    }

    var newFields: []const StructField = &.{};

    for (decls) |d| {
        newFields = newFields ++ &[_]StructField{.{ .name = d.name, .type = @TypeOf(@field(d.parent_type, d.name)), .default_value = &@field(d.parent_type, d.name), .is_comptime = true, .alignment = @alignOf(@TypeOf(@field(d.parent_type, d.name))) }};
    }

    return @Type(.{ .Struct = .{ .layout = .Auto, .fields = newFields, .decls = &.{}, .is_tuple = false } });
}
