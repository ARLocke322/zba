const std = @import("std");

pub const Cpu = struct {
    r: [16]u32,

    pub fn init() Cpu {
        return Cpu{ .r = [_]u32{0} ** 16 };
    }

    pub fn decode_execute(self: *Cpu, instruction: u32) !void {
        const cond: u4 = @truncate(instruction >> 28);
        switch (cond) {
            0xF => { // unconditional

            },
            else => { // conditional
                try self.de_conditional(instruction);
            },
        }
    }

    pub fn set_reg(self: *Cpu, index: usize, value: u32) void {
        self.r[index] = value;
    }

    fn de_conditional(self: *Cpu, instruction: u32) !void {
        const op1: u3 = @truncate((instruction >> 25) & 0x07); // Bits 25-27
        switch (op1) {
            0x00...0x01 => { // 00x
                try self.de_dp(instruction);
            },
            0x02 => { // 010
            },
            0x03 => { // 011
            },
            0x04...0x05 => { // 10x
            },
            0x06...0x07 => { // 11x
            },
        }
    }

    fn de_dp(self: *Cpu, instruction: u32) !void { // Data Processing & Misc
        const op: u1 = @truncate((instruction >> 25) & 0x01);
        const op1: u5 = @truncate((instruction >> 20) & 0x1F);
        switch (op) {
            0 => {},
            1 => {
                switch (op1) {
                    0x10 => {},
                    0x14 => {},
                    0x12, 0x16 => {},
                    else => {
                        try self.de_dp_imm(instruction);
                    },
                }
            },
        }
    }

    fn de_dp_imm(self: *Cpu, instruction: u32) !void {
        if ((instruction >> 25) & 0x07 != 0x1) return error.InvalidOpcode;
        // const cond: u4 = @truncate(instruction >> 28); // 28-31
        const op: u5 = @truncate((instruction >> 20) & 0x1F); // 20-24
        const r_n: u4 = @truncate((instruction >> 16) & 0x0F); // 16-19
        switch (op) {
            0x00...0x01 => { // Bitwise AND
                // ARM
                // const s: u1 = (instruction >> 20) & 0x01; // 20
                const r_d: u4 = @truncate((instruction >> 12) & 0x0F); // 12-15
                const imm12: u12 = @truncate((instruction & 0xFFF));

                if (Cpu.eval_cond()) {
                    self.r[r_d] = self.r[r_n] & Cpu.expand_imm(imm12);
                }
            },
            else => {},
        }
    }

    pub fn expand_imm(imm12: u12) u32 {
        const rotation = (imm12 >> 8) * 2;
        const imm8: u32 = imm12 & 0xFF;
        return std.math.rotr(u32, imm8, rotation);
    }

    fn eval_cond() bool {
        return true;
    }
};
