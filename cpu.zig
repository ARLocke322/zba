const std = @import("std");

pub const Cpu = struct {
    r: [16]u32,
    cpsr: [32]u1,

    pub fn init() Cpu {
        return Cpu{ .r = [_]u32{0} ** 16, .cpsr = [_]u1{0} ** 32 };
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
        @setRuntimeSafety(false);
        if ((instruction >> 25) & 0x07 != 0x1) return error.InvalidOpcode;
        // const cond: u4 = @truncate(instruction >> 28); // 28-31
        const op: u5 = @truncate((instruction >> 20) & 0x1F); // 20-24
        const r_n: u4 = @truncate((instruction >> 16) & 0x0F); // 16-19
        const s: u1 = @truncate((instruction >> 20) & 0x01); // 20
        const r_d: u4 = @truncate((instruction >> 12) & 0x0F); // 12-15
        const imm12: u12 = @truncate((instruction & 0xFFF)); // 0-11
        switch (op) {
            0x0, 0x1, 0x11 => { // Bitwise AND, TST
                // ARM
                const result = self.r[r_n] & Cpu.expand_imm(imm12);
                const not_test = (instruction >> 24) & 1 == 0;
                if (not_test) self.r[r_d] = result;
                if (s == 1) {
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if ((result >> 31) & 1 == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            },
            0x2, 0x3, 0x13 => { // Bitwise XOR, TEQ
                // ARM
                const result = self.r[r_n] ^ Cpu.expand_imm(imm12);
                const not_test = (instruction >> 24) & 1 == 0;
                if (not_test) self.r[r_d] = result;
                if (s == 1) {
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if ((result >> 31) & 1 == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            },
            0x4, 0x5, 0x6, 0x7, 0xC, 0xD, 0xE, 0xF, 0x15 => {
                // Subtract / Form PC-relative address / reverse sub
                const reverse: bool = (instruction >> 21) & 0x01 == 1;
                const carry: bool = (instruction >> 22) & 0x01 == 1;
                const not_compare: bool = (instruction >> 24) & 1 == 0;

                const op1: u32 = if (reverse) Cpu.expand_imm(imm12) else self.r[r_n];
                const op2: u32 = if (reverse) self.r[r_n] else Cpu.expand_imm(imm12);

                const result = if (carry)
                    op1 - op2 - @as(u32, (1 - self.cpsr[29]))
                else
                    op1 - op2;

                if (not_compare) self.r[r_d] = result;

                if (s == 1) {
                    const sign1 = (op1 >> 31) & 1;
                    const sign2 = (op2 >> 31) & 1;
                    const signr = (result >> 31) & 1;

                    if (sign1 != sign2 and sign1 != signr) {
                        self.cpsr[28] = 1;
                    } else self.cpsr[28] = 0;

                    if (op1 >= op2) {
                        self.cpsr[29] = 1;
                    } else self.cpsr[29] = 0;
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if (signr == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            },
            0x8, 0x9, 0xA, 0xB, 0x17 => {
                const carry: bool = (instruction >> 21) & 0x01 == 1;
                const not_compare: bool = (instruction >> 24) & 1 == 0;
                // ARM
                const op1: u32 = self.r[r_n];
                const op2: u32 = Cpu.expand_imm(imm12);

                const result = if (carry) op1 + op2 else op1 + op2 + self.cpsr[29];
                if (not_compare) self.r[r_d] = result;

                if (s == 1) {
                    const sign1 = (op1 >> 31) & 1;
                    const sign2 = (op2 >> 31) & 1;
                    const signr = (result >> 31) & 1;

                    if (sign1 == sign2 and sign1 != signr) {
                        self.cpsr[28] = 1;
                    } else self.cpsr[28] = 0;

                    if (result < op1) {
                        self.cpsr[29] = 1;
                    } else self.cpsr[29] = 0;
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if (signr == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            }, // Add / Form PC-relative address
            0x10, 0x12, 0x14, 0x16 => {}, // DP Misc
            0x18, 0x19 => { // Bitwise OR
            },
            0x1A, 0x1B => { // Move
                const result = Cpu.expand_imm(imm12);
                self.r[r_d] = result;
                if (s == 1) {
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if ((result >> 31) & 1 == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            },
            0x1C, 0x1D => { // Bitwise Bit Clear
                const result = self.r[r_n] & ~Cpu.expand_imm(imm12);
                self.r[r_d] = result;
                if (s == 1) {
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if ((result >> 31) & 1 == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            },
            0x1E, 0x1F => { // Bitwise NOT
                const result = ~Cpu.expand_imm(imm12);
                self.r[r_d] = result;
                if (s == 1) {
                    if (result == 0) {
                        self.cpsr[30] = 1;
                    } else self.cpsr[30] = 0;

                    if ((result >> 31) & 1 == 1) {
                        self.cpsr[31] = 1;
                    } else self.cpsr[31] = 0;
                }
            },
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
