const std = @import("std");
const sdl = @import("zsdl2");
const key_mod = @import("key.zig");

pub const Key = key_mod.Key;
pub const KeyKind = key_mod.KeyKind;
pub const Modifier = key_mod.Modifier;

const KMOD_LSHIFT: u16 = 0x0001;
const KMOD_RSHIFT: u16 = 0x0002;
const KMOD_LCTRL:  u16 = 0x0040;
const KMOD_RCTRL:  u16 = 0x0080;
const KMOD_LALT:   u16 = 0x0100;
const KMOD_RALT:   u16 = 0x0200;

/// Преобразовать SDL key-mods в наш Modifier.
pub fn modsFromSdl(sdl_mod: u16) Modifier {
    return .{
        .shift = (sdl_mod & (KMOD_LSHIFT | KMOD_RSHIFT)) != 0,
        .ctrl  = (sdl_mod & (KMOD_LCTRL | KMOD_RCTRL)) != 0,
        .alt   = (sdl_mod & (KMOD_LALT | KMOD_RALT)) != 0,
    };
}

/// Специальные клавиши — через key_down.
/// Обычные символы приходят как text_input, их обрабатываем отдельно.
pub fn keyFromKeyDown(k: sdl.KeyboardEvent) ?Key {
    const mods = modsFromSdl(k.keysym.mod);

    const kind: ?KeyKind = switch (k.keysym.sym) {
        .up        => .arrow_up,
        .down      => .arrow_down,
        .left      => .arrow_left,
        .right     => .arrow_right,
        .home      => .home,
        .end       => .end,
        .pageup    => .page_up,
        .pagedown  => .page_down,
        .insert    => .insert,
        .delete    => .delete,
        .escape    => .escape,
        .@"return" => .enter,
        .tab       => .tab,
        .backspace => .backspace,
        .f1  => .f1,  .f2  => .f2,  .f3  => .f3,  .f4  => .f4,
        .f5  => .f5,  .f6  => .f6,  .f7  => .f7,  .f8  => .f8,
        .f9  => .f9,  .f10 => .f10, .f11 => .f11, .f12 => .f12,
        else => null, // обычные символы приходят через text_input
    };

    if (kind) |k_| {
        return Key{ .kind = k_, .mods = mods };
    }

    // Обычные символы с Ctrl/Alt: SDL не присылвает для них text_input, поэтому возвращаем Key тут
    if (mods.ctrl or mods.alt) {
        const sym_signed: c_int = @intFromEnum(k.keysym.sym);
        if (sym_signed >= 0x20 and sym_signed < 0x7f) {
            return Key {
                .kind = .char,
                .char = @intCast(sym_signed),
                .mods = mods,
            };
        }
    }

    return null;
}

/// Обычные печатаемые символы приходят как text_input (UTF-8).
/// Пока поддерживаем только ASCII.
pub fn keyFromTextInput(t: sdl.TextInputEvent, mods: Modifier) ?Key {
    for (t.text) |b| {
        if (b == 0) break;
        if (b >= 0x20 and b < 0x7f) {
            return Key{ .kind = .char, .char = b, .mods = mods };
        }
    }
    return null;
}
