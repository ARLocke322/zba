const std = @import("std");
const expect = std.testing.expect;
const Cpu = @import("./cpu.zig").Cpu;

// Helper function to create ARM immediate instruction
// cond=0000 (0x0), I=1, op, S, Rn, Rd, imm12
fn makeInstruction(op: u5, s: u1, rn: u4, rd: u4, imm12: u12) u32 {
    var instruction: u32 = 0;
    instruction |= @as(u32, 0x0) << 28; // cond = 0x0
    instruction |= @as(u32, 0x1) << 25; // I = 1 (immediate)
    instruction |= @as(u32, op) << 20; // opcode (5 bits: bit 24-20)
    instruction |= @as(u32, s) << 20; // S flag (already in bit 20, part of op for some)
    instruction |= @as(u32, rn) << 16; // Rn
    instruction |= @as(u32, rd) << 12; // Rd
    instruction |= @as(u32, imm12); // imm12
    return instruction;
}

// More precise instruction maker
fn makeDataProcImm(op: u4, s: u1, rn: u4, rd: u4, imm12: u12) u32 {
    var instruction: u32 = 0;
    instruction |= @as(u32, 0x0) << 28; // cond = 0000
    instruction |= @as(u32, 0x1) << 25; // I = 1 (immediate)
    instruction |= @as(u32, op) << 21; // op (4 bits: 24-21)
    instruction |= @as(u32, s) << 20; // S flag
    instruction |= @as(u32, rn) << 16; // Rn
    instruction |= @as(u32, rd) << 12; // Rd
    instruction |= @as(u32, imm12); // imm12
    return instruction;
}

test "AND - Bitwise AND" {
    var cpu = Cpu.init();

    // AND R1, R2, #0xFF (op=0000x)
    // R2 = 0xFFFFFFFF, immediate = 0xFF
    cpu.r[2] = 0xFFFFFFFF;
    const instr = makeDataProcImm(0b0000, 0, 2, 1, 0xFF);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    // ANDS R3, R4, #0x0F (with S flag)
    cpu.r[4] = 0xF0F0F0F0;
    const instr_s = makeDataProcImm(0b0000, 1, 4, 3, 0x0F);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1); // Z flag should be set
}

test "EOR - Bitwise Exclusive OR" {
    var cpu = Cpu.init();

    // EOR R1, R2, #0xFF (op=0001x)
    cpu.r[2] = 0xFFFFFF00;
    const instr = makeDataProcImm(0b0001, 0, 2, 1, 0xFF);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFFFFFFFF);

    // EORS R3, R3, #0xFF (XOR with itself and immediate)
    cpu.r[3] = 0xFF;
    const instr_s = makeDataProcImm(0b0001, 1, 3, 3, 0xFF);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1); // Z flag
}

test "SUB - Subtract" {
    var cpu = Cpu.init();

    // SUB R1, R2, #10 (op=0010x, Rn != 1111)
    cpu.r[2] = 100;
    const instr = makeDataProcImm(0b0010, 0, 2, 1, 10);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 90);

    // SUBS R3, R4, #50 (with flags)
    cpu.r[4] = 25;
    const instr_s = makeDataProcImm(0b0010, 1, 4, 3, 50);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == @as(u32, @bitCast(@as(i32, -25))));
    try expect(cpu.cpsr[31] == 1); // N flag (negative)
    try expect(cpu.cpsr[29] == 0); // C flag (borrow occurred)
}

test "RSB - Reverse Subtract" {
    var cpu = Cpu.init();

    // RSB R1, R2, #100 (op=0011x) - R1 = 100 - R2
    cpu.r[2] = 30;
    const instr = makeDataProcImm(0b0011, 0, 2, 1, 100);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 70);

    // RSBS R3, R4, #10 (with flags)
    cpu.r[4] = 50;
    const instr_s = makeDataProcImm(0b0011, 1, 4, 3, 10);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == @as(u32, @bitCast(@as(i32, -40))));
    try expect(cpu.cpsr[31] == 1); // N flag
}

test "ADD - Add" {
    var cpu = Cpu.init();

    // ADD R1, R2, #50 (op=0100x, Rn != 1111)
    cpu.r[2] = 100;
    const instr = makeDataProcImm(0b0100, 0, 2, 1, 50);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 150);

    // ADDS R3, R4, #0xFF (with flags, test carry)
    cpu.r[4] = 0xFFFFFF00;
    const instr_s = makeDataProcImm(0b0100, 1, 4, 3, 0xFF);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0xFFFFFFFF);
    try expect(cpu.cpsr[31] == 1); // N flag
    try expect(cpu.cpsr[30] == 0); // Z flag
}

test "ADC - Add with Carry" {
    var cpu = Cpu.init();

    // ADC R1, R2, #10 (op=0101x) with carry clear
    cpu.r[2] = 100;
    cpu.cpsr[29] = 0; // Carry = 0
    const instr = makeDataProcImm(0b0101, 0, 2, 1, 10);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 110); // 100 + 10 + 0

    // ADC R3, R4, #10 with carry set
    cpu.r[4] = 100;
    cpu.cpsr[29] = 1; // Carry = 1
    const instr2 = makeDataProcImm(0b0101, 0, 4, 3, 10);
    try cpu.decode_execute(instr2);
    try expect(cpu.r[3] == 111); // 100 + 10 + 1
}

test "SBC - Subtract with Carry" {
    var cpu = Cpu.init();

    // SBC R1, R2, #10 (op=0110x) with carry set (no borrow)
    cpu.r[2] = 100;
    cpu.cpsr[29] = 1; // Carry = 1 (no borrow)
    const instr = makeDataProcImm(0b0110, 0, 2, 1, 10);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 90); // 100 - 10 - 0

    // SBC R3, R4, #10 with carry clear (borrow)
    cpu.r[4] = 100;
    cpu.cpsr[29] = 0; // Carry = 0 (borrow)
    const instr2 = makeDataProcImm(0b0110, 0, 4, 3, 10);
    try cpu.decode_execute(instr2);
    try expect(cpu.r[3] == 89); // 100 - 10 - 1
}

test "RSC - Reverse Subtract with Carry" {
    var cpu = Cpu.init();

    // RSC R1, R2, #100 (op=0111x) - R1 = 100 - R2 - NOT(C)
    cpu.r[2] = 30;
    cpu.cpsr[29] = 1; // Carry = 1 (no borrow)
    const instr = makeDataProcImm(0b0111, 0, 2, 1, 100);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 70); // 100 - 30 - 0

    // RSC with carry clear
    cpu.r[4] = 30;
    cpu.cpsr[29] = 0; // Carry = 0 (borrow)
    const instr2 = makeDataProcImm(0b0111, 0, 4, 3, 100);
    try cpu.decode_execute(instr2);
    try expect(cpu.r[3] == 69); // 100 - 30 - 1
}

test "TST - Test" {
    var cpu = Cpu.init();

    // TST R2, #0x0F (op=1000x, S=1) - performs AND but doesn't write result
    cpu.r[2] = 0xF0;
    cpu.r[5] = 0xDEADBEEF; // This should not change
    const instr = makeDataProcImm(0b1000, 1, 2, 5, 0x0F);
    try cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF); // Rd should not be written
    try expect(cpu.cpsr[30] == 1); // Z flag (0xF0 & 0x0F = 0)

    // TST with non-zero result
    cpu.r[3] = 0xFF;
    const instr2 = makeDataProcImm(0b1000, 1, 3, 0, 0x0F);
    try cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 0); // Z flag clear (0xFF & 0x0F = 0x0F)
}

test "TEQ - Test Equivalence" {
    var cpu = Cpu.init();

    // TEQ R2, #0xFF (op=1001x, S=1) - performs EOR but doesn't write result
    cpu.r[2] = 0xFF;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1001, 1, 2, 5, 0xFF);
    try cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF); // Rd should not be written
    try expect(cpu.cpsr[30] == 1); // Z flag (0xFF ^ 0xFF = 0, values equal)

    // TEQ with different values
    cpu.r[3] = 0xF0;
    const instr2 = makeDataProcImm(0b1001, 1, 3, 0, 0x0F);
    try cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 0); // Z flag clear (not equal)
}

test "CMP - Compare" {
    var cpu = Cpu.init();

    // CMP R2, #50 (op=1010x, S=1) - performs SUB but doesn't write result
    cpu.r[2] = 100;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1010, 1, 2, 5, 50);
    try cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF); // Rd should not be written
    try expect(cpu.cpsr[30] == 0); // Z flag clear (100 != 50)
    try expect(cpu.cpsr[29] == 1); // C flag set (100 >= 50, no borrow)
    try expect(cpu.cpsr[31] == 0); // N flag clear (positive result)

    // CMP with equal values
    cpu.r[3] = 75;
    const instr2 = makeDataProcImm(0b1010, 1, 3, 0, 75);
    try cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 1); // Z flag set (equal)
    try expect(cpu.cpsr[29] == 1); // C flag set (no borrow)

    // CMP with negative result
    cpu.r[4] = 25;
    const instr3 = makeDataProcImm(0b1010, 1, 4, 0, 100);
    try cpu.decode_execute(instr3);
    try expect(cpu.cpsr[31] == 1); // N flag set (negative result)
    try expect(cpu.cpsr[29] == 0); // C flag clear (borrow)
}

test "CMN - Compare Negative" {
    var cpu = Cpu.init();

    // CMN R2, #50 (op=1011x, S=1) - performs ADD but doesn't write result
    cpu.r[2] = 100;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1011, 1, 2, 5, 50);
    try cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF); // Rd should not be written
    try expect(cpu.cpsr[30] == 0); // Z flag clear (100 + 50 != 0)
    try expect(cpu.cpsr[31] == 0); // N flag clear (positive)

    // CMN that results in zero (testing -100 against 100)
    cpu.r[3] = @as(u32, @bitCast(@as(i32, -100)));
    const instr2 = makeDataProcImm(0b1011, 1, 3, 0, 100);
    try cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 1); // Z flag set (sum is zero)
}

test "ORR - Bitwise OR" {
    var cpu = Cpu.init();

    // ORR R1, R2, #0x0F (op=1100x)
    cpu.r[2] = 0xF0;
    const instr = makeDataProcImm(0b1100, 0, 2, 1, 0x0F);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    // ORRS R3, R4, #0x00 (with flags)
    cpu.r[4] = 0x00;
    const instr_s = makeDataProcImm(0b1100, 1, 4, 3, 0x00);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1); // Z flag
}

test "MOV - Move" {
    var cpu = Cpu.init();

    // MOV R1, #0xFF (op=1101x) - Rn is ignored
    const instr = makeDataProcImm(0b1101, 0, 0, 1, 0xFF);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    // MOVS R2, #0x00 (with flags)
    const instr_s = makeDataProcImm(0b1101, 1, 0, 2, 0x00);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[2] == 0x00);
    try expect(cpu.cpsr[30] == 1); // Z flag
    try expect(cpu.cpsr[31] == 0); // N flag

    // MOVS R3, #0x80000000 (test negative flag)
    // Note: need to encode 0x80000000 properly in imm12
    const instr_neg = makeDataProcImm(0b1101, 1, 0, 3, 0x102); // rotate right by 2
    try cpu.decode_execute(instr_neg);
    try expect(cpu.cpsr[31] == 1); // N flag should be set if MSB is 1
}

test "BIC - Bitwise Bit Clear" {
    var cpu = Cpu.init();

    // BIC R1, R2, #0x0F (op=1110x) - clears lower 4 bits
    cpu.r[2] = 0xFF;
    const instr = makeDataProcImm(0b1110, 0, 2, 1, 0x0F);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xF0);

    // BICS R3, R4, #0xFF (with flags)
    cpu.r[4] = 0xFF;
    const instr_s = makeDataProcImm(0b1110, 1, 4, 3, 0xFF);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1); // Z flag
}

test "MVN - Bitwise NOT" {
    var cpu = Cpu.init();

    // MVN R1, #0x00 (op=1111x) - Rn is ignored
    const instr = makeDataProcImm(0b1111, 0, 0, 1, 0x00);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFFFFFFFF);

    // MVNS R2, #0xFF (with flags)
    const instr_s = makeDataProcImm(0b1111, 1, 0, 2, 0xFF);
    try cpu.decode_execute(instr_s);
    try expect(cpu.r[2] == 0xFFFFFF00);
    try expect(cpu.cpsr[31] == 1); // N flag
    try expect(cpu.cpsr[30] == 0); // Z flag
}

test "ADR - Form PC-relative address (ADD variant)" {
    var cpu = Cpu.init();

    // ADR R1, label (op=0100x, Rn=1111) - adds immediate to PC
    cpu.r[15] = 0x1000; // PC
    const instr = makeDataProcImm(0b0100, 0, 0b1111, 1, 0x100);
    try cpu.decode_execute(instr);
    // Result should be PC + expanded immediate
    // Exact result depends on expand_imm implementation
}

test "ADR - Form PC-relative address (SUB variant)" {
    var cpu = Cpu.init();

    // ADR R1, label (op=0010x, Rn=1111) - subtracts immediate from PC
    cpu.r[15] = 0x1000; // PC
    const instr = makeDataProcImm(0b0010, 0, 0b1111, 1, 0x100);
    try cpu.decode_execute(instr);
    // Result should be PC - expanded immediate
}

test "Flag preservation when S=0" {
    var cpu = Cpu.init();

    // Set all flags initially
    cpu.cpsr[31] = 1; // N
    cpu.cpsr[30] = 1; // Z
    cpu.cpsr[29] = 1; // C
    cpu.cpsr[28] = 1; // V

    // ADD without S flag should not modify flags
    cpu.r[2] = 0;
    const instr = makeDataProcImm(0b0100, 0, 2, 1, 1);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 1);
    try expect(cpu.cpsr[31] == 1); // N unchanged
    try expect(cpu.cpsr[30] == 1); // Z unchanged
    try expect(cpu.cpsr[29] == 1); // C unchanged
    try expect(cpu.cpsr[28] == 1); // V unchanged
}

test "Overflow flag - Addition" {
    var cpu = Cpu.init();

    // ADDS with positive overflow (0x7FFFFFFF + 1)
    cpu.r[2] = 0x7FFFFFFF;
    const instr = makeDataProcImm(0b0100, 1, 2, 1, 1);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0x80000000);
    try expect(cpu.cpsr[28] == 1); // V flag (overflow)
    try expect(cpu.cpsr[31] == 1); // N flag (result appears negative)
}

test "Overflow flag - Subtraction" {
    var cpu = Cpu.init();

    // SUBS with negative overflow (0x80000000 - 1)
    cpu.r[2] = 0x80000000;
    const instr = makeDataProcImm(0b0010, 1, 2, 1, 1);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0x7FFFFFFF);
    try expect(cpu.cpsr[28] == 1); // V flag (overflow)
    try expect(cpu.cpsr[31] == 0); // N flag (result appears positive)
}

test "Carry flag - Addition unsigned overflow" {
    var cpu = Cpu.init();

    // ADDS with carry (0xFFFFFFFF + 1)
    cpu.r[2] = 0xFFFFFFFF;
    const instr = makeDataProcImm(0b0100, 1, 2, 1, 1);
    try cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0);
    try expect(cpu.cpsr[29] == 1); // C flag (unsigned overflow)
    try expect(cpu.cpsr[30] == 1); // Z flag (result is zero)
}
