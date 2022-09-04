const ansi = @import("ansi.zig");

pub const red = ansi.colorWGen(.red, null);
pub const redi = ansi.colorWMGen(.red, null, .italic);
pub const target = ansi.colorWGen(.yellow, null);
pub const targeti = ansi.colorWMGen(.yellow, null, .italic);
pub const validator = ansi.colorWGen(.green, null);
pub const validatori = ansi.colorWMGen(.green, null, .italic);
pub const normal = ansi.colorWMGen(.white, null, .bold);