const Cpu = @import("./cpu.zig").Cpu;
const std = @import("std");

pub fn main() !void {
    var cpu = Cpu.init();
    // const instruction: u32 = 0xE201_50FF;
    const instruction: u32 = 0x021150FF;
    cpu.set_reg(1, 0xFFFFFFFF);
    std.debug.print("{any}\n", .{cpu.r});
    try cpu.decode_execute(instruction);
    std.debug.print("{any}\n", .{cpu.r});
    const imm12: u12 = @truncate((instruction & 0xFFF));
    std.debug.print("imm12: 0x{x}, expanded: 0x{x}\n", .{ imm12, Cpu.expand_imm(imm12) });
}
