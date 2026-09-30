const std = @import("std");

pub const KeyKind = enum {
    char,
    enter,
    tab,
    backspace,
    escape,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    home,
    end,
    page_up,
    page_down,
    insert,
    delete,
    f1, f2, f3, f4,
    f5, f6, f7, f8,
    f9, f10, f11, f12,
    unknown,
};

pub const Modifier = struct {
    shift: bool = false,
    alt: bool = false,
    ctrl: bool = false,

    pub fn toBits(self: Modifier) u3 {
        var bits: u3 = 0;

        if (self.shift) bits |= 1;
        if (self.alt) bits |= 2;
        if (self.ctrl) bits |= 4;

        return bits;
    }

    pub fn fromBits(bits: u3) Modifier {
        return .{
            .shift = (bits & 1) != 0,
            .alt = (bits & 2) != 0,
            .ctrl = (bits & 4) != 0,
        };
    }

    pub fn eql(a: Modifier, b: Modifier) bool {
        return (
            a.shift == b.shift
            and a.alt == b.alt
            and a.ctrl == b.ctrl
        );
    }
};

pub const Key = struct{
    kind: KeyKind = .unknown,
    char: u8 = 0,
    mods: Modifier = .{},

    pub fn eql(a: Key, b: Key) bool {
        return (
            a.kind == b.kind
            and a.char == b.char
            and Modifier.eql(a.mods, b.mods)
        );
    }

    // NOTE: разобраться как это работает
    /// FNV-1a. Годится для ключей в HashMap
    pub fn hash(self: Key) u64 {
        var h: u64 = 0xcbf29ce484222325;
        const prime: u64 = 0x100000001b3;

        h = (h ^ @as(u64, @intFromEnum(self.kind))) *% prime;
        h = (h ^ @as(u64, self.char)) *% prime;
        h = (h ^ @as(u64, self.mods.toBits())) *% prime;

        return h;
    }
};
