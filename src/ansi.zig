const std = @import("std");

pub const Color = enum(u8) {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    default = 9,
    pub fn foreground(self: @This()) [2]u8 {
        var val: [2]u8 = undefined;
        val[0] = '3';
        val[1] = '0' + @enumToInt(self);
        return val;
    }

    pub fn background(self: @This()) [2]u8 {
        var val: [2]u8 = undefined;
        val[0] = '4';
        val[1] = '0' + @enumToInt(self);
        return val;
    }
};

pub const Mode = enum(u8) {
    default = 0,
    bold = 1,
    dim = 2,
    italic = 3,
    underline = 4,
    blinking = 5,
    inverse = 7,
    hidden = 8,
    strikethrough = 9,
    pub fn set(self: @This()) [1]u8 {
        var val: [1]u8 = undefined;
        val[0] = '0' + @enumToInt(self);
        return val;
    }
};
pub fn reset() []const u8 {
    return "\x1b[0m";
}

pub fn colorW(comptime foreground: ?Color, comptime background: ?Color, comptime str: []const u8) []const u8 {
    return comptime color(foreground, background) ++ str ++ reset();
}

pub fn colorWGen(comptime foreground: ?Color, comptime background: ?Color) (fn (comptime []const u8) []const u8) {
    return struct {
        pub fn gen(comptime str: []const u8) []const u8 {
            return colorW(foreground, background, str);
        }
    }.gen;
}

pub fn colorWMGen(comptime foreground: ?Color, comptime background: ?Color, comptime style: Mode) (fn (comptime []const u8) []const u8) {
    return struct {
        pub fn gen(comptime str: []const u8) []const u8 {
            return colorWM(foreground, background, style, str);
        }
    }.gen;
}

pub fn colorWM(comptime foreground: ?Color, comptime background: ?Color, comptime style: Mode, comptime str: []const u8) []const u8 {
    return comptime mode(style) ++ colorW(foreground, background, str) ++ mode(.default);
}

pub fn mode(comptime style: Mode) []const u8 {
    return std.fmt.comptimePrint("\x1b[{s}m", .{style.set()});
}

pub fn color(comptime foreground: ?Color, comptime background: ?Color) []const u8 {
    comptime {
        if (foreground == null and background == null) return reset();
        var fgtext = if (foreground) |f| (f.foreground() ++ (if (background) |_| ";" else "")) else "";
        var bgtext = if (background) |b| b.background() else "";
        return std.fmt.comptimePrint("\x1b[1;{s}{s}m", .{ fgtext, bgtext });
    }
}

pub fn color256(comptime foreground: ?u8, comptime background: ?u8) []const u8 {
    comptime {
        var res: []const u8 = "\x1b[";
        if (foreground == null and background == null) return reset();
        if (foreground) |f| res = res ++ std.fmt.comptimePrint("38;5;{}", .{f});
        if (background) |b| res = res ++ std.fmt.comptimePrint("48;5;{ID}", .{b});
        return res ++ "m";
    }
}
pub fn colorRGB(comptime foreground: ?u24, comptime background: ?u34) []const u8 {
    comptime {
        var res: []const u8 = "\x1b[";
        if (foreground == null and background == null) return reset();
        if (foreground) |f| res = res ++ std.fmt.comptimePrint("38;2;{};{};{}", .{ f & 0xFF0000, f & 0x00FF00, f & 0x0000FF });
        if (background) |b| res = res ++ std.fmt.comptimePrint("48;2;{};{};{}", .{ b & 0xFF0000, b & 0x00FF00, b & 0x0000FF });
        return res ++ "m";
    }
}

test "ansi" {
    //const a: []const u8 = "\x1b[1;31m";
    //std.log.warn("{any} versus {any}", .{Ansi.color(.red, null), a});
    try std.testing.expect(std.mem.eql(u8, color(.red, null), "\x1b[1;31m"));
    // std.log.warn(color256(128, null) ++ "Hello" ++ color(null, null), .{});
    // std.log.warn(colorRGB(0xFF00FF, null) ++ "Goodbye" ++ color(null, null), .{});
}
