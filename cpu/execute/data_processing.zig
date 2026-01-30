const std = @import("std");

const Cpu = @import("../cpu.zig").Cpu;
const flags = @import("../flags.zig");

pub fn execute_AND(cpu: *Cpu, r_n: u4, r_d: u4, imm: u32, update_flags: bool, write: bool) void {
    const result = cpu.r[r_n] & imm;
    if (write) cpu.r[r_d] = result;
    if (update_flags) flags.update_NZ_flags(cpu, result);
}

pub fn execute_XOR(cpu: *Cpu, r_n: u4, r_d: u4, imm: u32, update_flags: bool, write: bool) void {
    const result = cpu.r[r_n] ^ imm;
    if (write) cpu.r[r_d] = result;
    if (update_flags) flags.update_NZ_flags(cpu, result);
}

pub fn execute_OR(cpu: *Cpu, r_n: u4, r_d: u4, imm: u32, update_flags: bool) void {
    const result = cpu.r[r_n] | imm;
    cpu.r[r_d] = result;
    if (update_flags) flags.update_NZ_flags(cpu, result);
}

pub fn execute_MOV(cpu: *Cpu, r_d: u4, imm: u32, update_flags: bool) void {
    const result = imm;
    cpu.r[r_d] = result;
    if (update_flags) flags.update_NZ_flags(cpu, result);
}

pub fn execute_BIC(cpu: *Cpu, r_n: u4, r_d: u4, imm: u32, update_flags: bool) void {
    const result = cpu.r[r_n] & ~imm;
    cpu.r[r_d] = result;
    if (update_flags) flags.update_NZ_flags(cpu, result);
}

pub fn execute_NOT(cpu: *Cpu, r_d: u4, imm: u32, update_flags: bool) void {
    const result = ~imm;
    cpu.r[r_d] = result;
    if (update_flags) flags.update_NZ_flags(cpu, result);
}

pub fn execute_ADD(
    cpu: *Cpu,
    r_n: u4,
    r_d: u4,
    imm: u32,
    update_flags: bool,
    write: bool,
    carry: bool,
) void {
    @setRuntimeSafety(false);
    const op1: u32 = cpu.r[r_n];
    const op2: u32 = imm;
    const result = if (carry) op1 + op2 + cpu.cpsr[29] else op1 + op2;

    if (write) cpu.r[r_d] = result;
    if (update_flags) flags.update_ADD_flags(cpu, op1, op2, result);
}

pub fn execute_SUB(
    cpu: *Cpu,
    r_n: u4,
    r_d: u4,
    imm: u32,
    update_flags: bool,
    write: bool,
    reverse: bool,
    carry: bool,
) void {
    @setRuntimeSafety(false);
    const op1: u32 = if (reverse) imm else cpu.r[r_n];
    const op2: u32 = if (reverse) cpu.r[r_n] else imm;

    const result = if (carry)
        op1 - op2 - @as(u32, (1 - cpu.cpsr[29]))
    else
        op1 - op2;

    if (write) cpu.r[r_d] = result;
    if (update_flags) flags.update_SUB_flags(cpu, op1, op2, result);
}
