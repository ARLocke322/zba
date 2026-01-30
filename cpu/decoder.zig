const std = @import("std");
const Cpu = @import("./cpu.zig").Cpu;
const data_processing = @import("execute/data_processing.zig");
const load_store = @import("execute/load_store.zig");
const helpers = @import("helpers.zig");

pub fn decode_execute(cpu: *Cpu, instruction: u32) void {
    // std.debug.print("Executing instruction: 0x{x}\n", .{instruction});
    // const cond: u4 = @truncate(instruction >> 28);
    // const op: u1 = @truncate((instruction >> 25) & 0x01);
    const op1: u3 = @truncate((instruction >> 26) & 0x3);
    switch (op1) {
        0x0 => decode_data_processing(cpu, instruction),
        0x1 => decode_load_store_word(cpu, instruction),
        else => {},
    }
}

pub fn decode_data_processing(cpu: *Cpu, instruction: u32) void {
    const op: u1 = @truncate((instruction >> 25) & 0x01);
    switch (op) {
        0x0 => {},
        0x1 => decode_immediate_processing(cpu, instruction),
    }
}

pub fn decode_immediate_processing(cpu: *Cpu, instruction: u32) void {
    const op1: u5 = @truncate(instruction >> 20);
    switch (op1) {
        0x10 => {},
        0x14 => {},
        0x12, 0x16 => {},
        else => decode_immediate_data_processing(cpu, instruction),
    }
}

pub fn decode_load_store_word(cpu: *Cpu, instruction: u32) void {
    const a: u1 = @truncate((instruction >> 25) & 0x01);
    const op1: u1 = @truncate((instruction >> 20) & 0x1);
    const r_n: u4 = @truncate((instruction >> 16) & 0xF);
    const r_t: u4 = @truncate((instruction >> 12) & 0xF);
    const imm: u12 = @truncate(instruction & 0xFFF);
    const p: u1 = @truncate((instruction >> 24) & 1);
    const u: u1 = @truncate((instruction >> 23) & 1);
    const w: u1 = @truncate((instruction >> 21) & 1);

    const register = a == 1;
    const add_offset = u == 1;
    const pre_indexed = p == 1;
    const writeback = w == 1 or p == 0; // possible invalid command when w=1 && p=0

    const byte: u1 = @truncate(instruction >> 22);
    const size: u6 = switch (byte) {
        0x0 => 0x20,
        0x1 => 0x08,
    };

    switch (op1) {
        0x0 => { // ignore unprivileged for now
            load_store.execute_STR(cpu, r_n, r_t, imm, register, pre_indexed, writeback, add_offset, size);
        },
        0x1 => {
            load_store.execute_LDR(cpu, r_n, r_t, imm, register, pre_indexed, writeback, add_offset, size);
        },
    }
}

pub fn read_data(cpu: *Cpu, address: u32, size: u6) u32 {
    return switch (size) {
        0x20 => cpu.mem.read32(address),
        0x10 => @as(u32, cpu.mem.read16(address)),
        0x8 => @as(u32, cpu.mem.read8(address)),
        else => unreachable,
    };
}

pub fn write_data(cpu: *Cpu, data: u32, address: u32, size: u6) void {
    switch (size) {
        0x20 => cpu.mem.write32(data, address),
        0x10 => cpu.mem.write16(data, address),
        0x8 => cpu.mem.write8(data, address),
        else => {},
    }
}

pub fn decode_immediate_data_processing(cpu: *Cpu, instruction: u32) void {
    // MANUAL INCLUDES S IN OP, I REMOVED IT
    const op: u4 = @truncate((instruction >> 21) & 0xF); // 21-24
    const r_n: u4 = @truncate((instruction >> 16) & 0xF); // 16-19
    const s: u1 = @truncate((instruction >> 20) & 0x1); // 20
    const r_d: u4 = @truncate((instruction >> 12) & 0xF); // 12-15
    const imm12: u12 = @truncate((instruction & 0xFFF)); // 0-11

    const update_flags: bool = s == 1;
    const write = switch (op) {
        0x8, 0x9, 0xA, 0xB => false, // TST, TEQ, CMP, CMN
        else => true,
    };
    const reverse = op == 0x3 or op == 0x7; // RSB, RSC
    const carry = op == 0x5 or op == 0x6 or op == 0x7; // SBC, RSC, ADC

    switch (op) {
        0x0, 0x8 => data_processing.execute_AND(cpu, r_n, r_d, helpers.expand_imm(imm12), update_flags, write),
        0x1, 0x9 => data_processing.execute_XOR(cpu, r_n, r_d, helpers.expand_imm(imm12), update_flags, write),
        0x2, 0x3, 0x6, 0x7, 0xA => data_processing.execute_SUB(cpu, r_n, r_d, helpers.expand_imm(imm12), update_flags, write, reverse, carry),
        0x4, 0x5, 0xB => data_processing.execute_ADD(cpu, r_n, r_d, helpers.expand_imm(imm12), update_flags, write, carry),
        0xC => data_processing.execute_OR(cpu, r_n, r_d, helpers.expand_imm(imm12), update_flags),
        0xD => data_processing.execute_MOV(cpu, r_d, helpers.expand_imm(imm12), update_flags),
        0xE => data_processing.execute_BIC(cpu, r_n, r_d, helpers.expand_imm(imm12), update_flags),
        0xF => data_processing.execute_NOT(cpu, r_d, helpers.expand_imm(imm12), update_flags),
    }
}
