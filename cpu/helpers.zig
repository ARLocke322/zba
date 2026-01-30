const std = @import("std");

pub fn expand_imm(imm12: u12) u32 {
    const rotation = (imm12 >> 8) * 2;
    const imm8: u32 = imm12 & 0xFF;
    return std.math.rotr(u32, imm8, rotation);
}
