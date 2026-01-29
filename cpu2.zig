const std = @import("std");

pub const Cpu = struct {
    r: [16]u32,
    cpsr: [32]u1,

    pub fn init() Cpu {
        return Cpu{ .r = [_]u32{0} ** 16, .cpsr = [_]u1{0} ** 32 };
    }

    pub fn decode_execute(self: *Cpu, instruction: u32) void {
        // const cond: u4 = @truncate(instruction >> 28);
        // const op: u1 = @truncate((instruction >> 25) & 0x01);
        const op1: u5 = @truncate((instruction >> 20) & 0x1F);
        switch (op1) {
            0x0, 0x1 => { // Data processing & Misc
                try self.decode_data_processing(instruction);
            },
            else => {},
        }
    }

    fn decode_data_processing(self: *Cpu, instruction: u32) void {
        const op: u1 = @truncate((instruction >> 25) & 0x01);
        switch (op) {
            0x0 => {},
            0x1 => try self.decode_immediate_processing(instruction),
        }
    }

    fn decode_immediate_processing(self: *Cpu, instruction: u32) void {
        const op1: u1 = @truncate((instruction >> 20) & 0x1F);
        switch (op1) {
            0x10 => {},
            0x14 => {},
            0x14 => {},
            0x12, 0x16 => {},
            else => self.decode_immediate_data_processing(instruction),
        }
    }

    fn decode_immediate_data_processing(self: *Cpu, instruction: u32) void {
        @setRuntimeSafety(false);
        // MANUAL INCLUDES S IN OP, I REMOVED IT
        const op: u5 = @truncate((instruction >> 21) & 0xF); // 21-24
        const r_n: u4 = @truncate((instruction >> 16) & 0x0F); // 16-19
        const s: u1 = @truncate((instruction >> 20) & 0x01); // 20
        const r_d: u4 = @truncate((instruction >> 12) & 0x0F); // 12-15
        const imm12: u12 = @truncate((instruction & 0xFFF)); // 0-11

        const update_flags: bool = s == 1;
        const write: bool = (op >> 4) & 1 == 1;
        const reverse: bool = (op >> 3) & 1 == 1;
        const carry: bool = (op >> 1) & 1 == 1;

        switch (op) {
            0x0, 0x8 => self.execute_AND(r_n, r_d, self.expand_imm(imm12), update_flags, write),
            0x1, 0x9 => self.execute_XOR(r_n, r_d, self.expand_imm(imm12), update_flags, write),
            0x2, 0x3, 0x6, 0x7, 0xA => self.execute_SUB(r_n, r_d, self.expand_imm(imm12), update_flags, write, reverse, carry),
            0x4, 0x5, 0xB => self.execute_ADD(r_n, r_d, self.expand_imm(imm12), update_flags, write, carry),
            0xC => self.execute_OR(r_n, r_d, self.expand_imm(imm12), update_flags),
            0xD => self.execute_MOV(r_d, self.expand_imm(imm12), update_flags),
            0xE => self.execute_BIC(r_n, r_d, self.expand_imm(imm12), update_flags),
            0xF => self.execute_NOT(r_d, self.expand_imm(imm12), update_flags),
        }
    }

    // --- EXECUTE METHODS ---

    fn execute_AND(self: *Cpu, r_n: u32, r_d: u32, imm: u32, update_flags: bool, write: bool) void {
        const result = self.r[r_n] & imm;
        if (write) self.r[r_d] = result;
        if (update_flags) self.update_NZ_flags(result);
    }

    fn execute_XOR(self: *Cpu, r_n: u32, r_d: u32, imm: u32, update_flags: bool, write: bool) void {
        const result = self.r[r_n] ^ imm;
        if (write) self.r[r_d] = result;
        if (update_flags) self.update_NZ_flags(result);
    }

    fn execute_OR(self: *Cpu, r_n: u32, r_d: u32, imm: u32, update_flags: bool) void {
        const result = self.r[r_n] | imm;
        self.r[r_d] = result;
        if (update_flags) self.update_NZ_flags(result);
    }

    fn execute_MOV(self: *Cpu, r_d: u32, imm: u32, update_flags: bool) void {
        const result = imm;
        self.r[r_d] = result;
        if (update_flags) self.update_NZ_flags(result);
    }

    fn execute_BIC(self: *Cpu, r_n: u32, r_d: u32, imm: u32, update_flags: bool) void {
        const result = self.r[r_n] & ~imm;
        self.r[r_d] = result;
        if (update_flags) self.update_NZ_flags(result);
    }

    fn execute_NOT(self: *Cpu, r_d: u32, imm: u32, update_flags: bool) void {
        const result = ~imm;
        self.r[r_d] = result;
        if (update_flags) self.update_NZ_flags(result);
    }

    fn execute_SUB(
        self: *Cpu,
        r_n: u32,
        r_d: u32,
        imm: u32,
        update_flags: bool,
        write: bool,
        reverse: bool,
        carry: bool,
    ) void {
        const op1: u32 = if (reverse) imm else self.r[r_n];
        const op2: u32 = if (reverse) self.r[r_n] else imm;

        const result = if (carry)
            op1 - op2 - @as(u32, (1 - self.cpsr[29]))
        else
            op1 - op2;

        if (write) self.r[r_d] = result;
        if (update_flags) self.update_SUB_flags(op1, op2, result);
    }

    fn execute_ADD(
        self: *Cpu,
        r_n: u32,
        r_d: u32,
        imm: u32,
        update_flags: bool,
        write: bool,
        carry: bool,
    ) void {
        const op1: u32 = self.r[r_n];
        const op2: u32 = imm;
        const result = if (carry) op1 + op2 else op1 + op2 + self.cpsr[29];

        if (write) self.r[r_d] = result;
        if (update_flags) self.update_ADD_flags(op1, op2, result);
    }

    // --- FLAG UPDATES ---

    fn update_NZ_flags(self: *Cpu, result: u32) void {
        if (result == 0) {
            self.cpsr[30] = 1;
        } else self.cpsr[30] = 0;

        if ((result >> 31) & 1 == 1) {
            self.cpsr[31] = 1;
        } else self.cpsr[31] = 0;
    }

    fn update_SUB_flags(self: *Cpu, op1: u32, op2: u32, result: u32) void {
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

    fn update_ADD_flags(self: *Cpu, op1: u32, op2: u32, result: u32) void {
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

    // --- MISC HELPERS ---

    pub fn expand_imm(imm12: u12) u32 {
        const rotation = (imm12 >> 8) * 2;
        const imm8: u32 = imm12 & 0xFF;
        return std.math.rotr(u32, imm8, rotation);
    }
};
