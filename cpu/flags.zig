const Cpu = @import("./cpu.zig").Cpu;

pub fn update_NZ_flags(cpu: *Cpu, result: u32) void {
    if (result == 0) {
        cpu.cpsr[30] = 1;
    } else cpu.cpsr[30] = 0;

    if ((result >> 31) & 1 == 1) {
        cpu.cpsr[31] = 1;
    } else cpu.cpsr[31] = 0;
}

pub fn update_SUB_flags(cpu: *Cpu, op1: u32, op2: u32, result: u32) void {
    const sign1 = (op1 >> 31) & 1;
    const sign2 = (op2 >> 31) & 1;
    const signr = (result >> 31) & 1;

    if (sign1 != sign2 and sign1 != signr) {
        cpu.cpsr[28] = 1;
    } else cpu.cpsr[28] = 0;

    if (op1 >= op2) {
        cpu.cpsr[29] = 1;
    } else cpu.cpsr[29] = 0;
    if (result == 0) {
        cpu.cpsr[30] = 1;
    } else cpu.cpsr[30] = 0;

    if (signr == 1) {
        cpu.cpsr[31] = 1;
    } else cpu.cpsr[31] = 0;
}

pub fn update_ADD_flags(cpu: *Cpu, op1: u32, op2: u32, result: u32) void {
    const sign1 = (op1 >> 31) & 1;
    const sign2 = (op2 >> 31) & 1;
    const signr = (result >> 31) & 1;
    if (sign1 == sign2 and sign1 != signr) {
        cpu.cpsr[28] = 1;
    } else cpu.cpsr[28] = 0;

    if (result < op1) {
        cpu.cpsr[29] = 1;
    } else cpu.cpsr[29] = 0;
    if (result == 0) {
        cpu.cpsr[30] = 1;
    } else cpu.cpsr[30] = 0;

    if (signr == 1) {
        cpu.cpsr[31] = 1;
    } else cpu.cpsr[31] = 0;
}
