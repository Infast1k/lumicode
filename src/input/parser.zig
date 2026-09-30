const std = @import("std");
const key_mod = @import("key.zig");

pub const Key = key_mod.Key;
pub const KeyKind = key_mod.KeyKind;
pub const Modifier = key_mod.Modifier;

pub const Parser = struct {
    state: State = .ground,
    params: [8]u8 = undefined,
    params_len: usize = 0,

    const State = enum {
        ground,  // Обычный режим
        escape,  // Получили ESC, ждем, что дальше
        csi,  // Получили ESC [, копим параметры до финального символа
        ss3,  // Получили ESC O, ждем финальный символ (F1-F4)
    };

    pub fn init() Parser {
        return .{};
    }

    pub fn reset(self: *Parser) void {
        self.state = .ground;
        self.params_len = 0;
    }

    pub fn feed(self: *Parser, byte: u8) ?Key {
        return switch (self.state) {
            .ground => self.handleGround(byte),
            .escape => self.handleEscape(byte),
            .csi => self.handleSci(byte),
            .ss3 => self.handleSs3(byte),
        };
    }

    // FIXME: разобраться зачем нужны break :blk
    fn handleGround(self: *Parser, byte: u8) ?Key {
        if (byte == 0x1b) {
            self.state = .escape;
            return null;
        }

        return switch (byte) {
            0x09 => Key{ .kind = .tab },
            0x0a, 0x0d => Key{ .kind = .enter },
            0x08, 0x7f => Key{ .kind = .backspace },
            else => blk: {
                // Ctrl+A ... Ctrl+Z = 0x01 ... 0x1a
                if (byte >= 0x01 and byte<=0x1a) {
                    break :blk Key{
                        .kind = .char,
                        .char = 'a' + (byte - 1),
                        .mods = .{ .ctrl = true },
                    };
                }

                // Печатаемый ASCII
                if (byte >= 0x20 and byte < 0x7f) {
                    break :blk Key{
                        .kind = .char,
                        .char = byte,
                    };
                }

                // FIXME: UTF-8 и прочие пока не разбираем
                break :blk Key{ .kind = .unknown };
            }
        };
    }

    fn handleEscape(self: *Parser, byte: u8) ?Key {
        if (byte == '[') {
            self.state = .csi;
            self.params_len = 0;
            return null;
        }

        if (byte == 'O') {
            self.state = .ss3;
            return null;
        }

        // ESC + печатаемый символ = Alt+символ
        if (byte >= 0x20 and byte < 0x7f) {
            self.state = .ground;
            return Key{
                .kind = .char,
                .char = byte,
                .mods = .{ .alt = true },
            };
        }

        self.state = .ground;
        return Key{ .kind = .escape };
    }

    fn handleSci(self: *Parser, byte: u8) ?Key {
        // Копим цифры и ';' в буфер параметров
        if ((byte >= '0' and byte <= '9') or byte == ';') {
            if (self.params_len < self.params.len) {
                self.params[self.params_len] = byte;
                self.params_len += 1;
            }

            return null;
        }

        // Любой другой символ - финальный. Разбираем.
        const final = byte;
        const params = self.params[0..self.params_len];
        self.reset();
        return self.resolveSci(params, final);
    }

    fn resolveSci(self: *Parser, params: []const u8, final: u8) ?Key {
        _ = self;

        // Разбираем до двух чисел, разделенных ';'.
        var nums: [2]u16 = .{ 0, 0 };
        var num_count: usize = 0;
        var i: usize = 0;
        while (i < params.len and num_count < 2) {
            var n: u16 = 0;
            var has_digit = false;
            while (i < params.len and params[i] != ';') {
                const c = params[i];
                if (c >= '0' and c <= '9') {
                    n = n * 10 + (c - '0');
                    has_digit = true;
                }

                i += 1;
            }

            if (has_digit) {
                nums[num_count] = n;
                num_count += 1;
            }

            if (i < params.len and params[i] == ';') {
                i += 1;
            }
        }

        var mods: Modifier = .{};
        if (num_count == 2 and nums[1] >= 1 and nums[1] <= 8) {
            const bits: u3 = @intCast(nums[1] - 1);
            mods = Modifier.fromBits(bits);
            // const bits: u3 = @intCast(nums[1] - 1);
            // mods.shift = (bits & 1) != 0;
            // mods.alt = (bits & 2) != 0;
            // mods.ctrl = (bits & 4) != 0;
        }

        const kind: KeyKind = switch (final) {
            'A' => .arrow_up,
            'B' => .arrow_down,
            'C' => .arrow_right,
            'D' => .arrow_left,
            'H' => .home,
            'F' => .end,
            '~' => blk: {
                if (num_count == 0) break :blk .unknown;
                break :blk switch(nums[0]) {
                    1, 7 => .home,
                    2 => .insert,
                    3 => .delete,
                    4, 8 => .end,
                    5 => .page_up,
                    6 => .page_down,
                    11 => .f1,
                    12 => .f2,
                    13 => .f3,
                    14 => .f4,
                    15 => .f5,
                    17 => .f6,
                    18 => .f7,
                    19 => .f8,
                    20 => .f9,
                    21 => .f10,
                    23 => .f11,
                    24 => .f12,
                    else => .unknown,
                };
            },
            else => .unknown,
        };

        return Key{
            .kind = kind,
            .mods = mods,
        };
    }

    fn handleSs3(self: *Parser, byte: u8) ?Key {
        self.state = .ground;

        return switch (byte) {
            'P' => Key{ .kind = .f1 },
            'Q' => Key{ .kind = .f2 },
            'R' => Key{ .kind = .f3 },
            'S' => Key{ .kind = .f4 },
            'A' => Key{ .kind = .arrow_up },
            'B' => Key{ .kind = .arrow_down },
            'C' => Key{ .kind = .arrow_right },
            'D' => Key{ .kind = .arrow_left },
            'H' => Key{ .kind = .home },
            'F' => Key{ .kind = .end },
            else => Key{ .kind = .unknown },
        };
    }
};
