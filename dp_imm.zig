const std = @import("std");
const expect = std.testing.expect;
const Cpu = @import("./cpu.zig").Cpu;

// --- HELPER FUNCTION TO BUILD FULL 32-BIT DATA-PROCESSING IMMEDIATE INSTRUCTION ---
fn makeDataProcImm(
    cond: u4, // condition bits (31-28), usually 0b1110 = AL
    op: u4, // opcode bits 24-21
    s: u1, // S flag (bit 20)
    rn: u4, // Rn (bits 19-16)
    rd: u4, // Rd (bits 15-12)
    imm12: u12, // immediate (bits 11-0)
) u32 {
    var instr: u32 = 0;
    instr |= @as(u32, cond) << 28; // cond[31:28]
    instr |= 0b001 << 25; // I = 1 for immediate
    instr |= @as(u32, op) << 21; // opcode[24:21]
    instr |= @as(u32, s) << 20; // S flag
    instr |= @as(u32, rn) << 16; // Rn[19:16]
    instr |= @as(u32, rd) << 12; // Rd[15:12]
    instr |= @as(u32, imm12); // imm12[11:0]
    return instr;
}

// --- TESTS ---

test "AND - Bitwise AND" {
    var cpu = Cpu.init();

    cpu.r[2] = 0xFFFFFFFF;
    const instr = makeDataProcImm(0b1110, 0b0000, 0, 2, 1, 0xFF);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    cpu.r[4] = 0xF0F0F0F0;
    const instr_s = makeDataProcImm(0b1110, 0b0000, 1, 4, 3, 0x0F);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1);
}

test "EOR - Bitwise Exclusive OR" {
    var cpu = Cpu.init();

    cpu.r[2] = 0xFFFFFF00;
    const instr = makeDataProcImm(0b1110, 0b0001, 0, 2, 1, 0xFF);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFFFFFFFF);

    cpu.r[3] = 0xFF;
    const instr_s = makeDataProcImm(0b1110, 0b0001, 1, 3, 3, 0xFF);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1);
}

test "SUB - Subtract" {
    var cpu = Cpu.init();

    cpu.r[2] = 100;
    const instr = makeDataProcImm(0b1110, 0b0010, 0, 2, 1, 10);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 90);

    cpu.r[4] = 25;
    const instr_s = makeDataProcImm(0b1110, 0b0010, 1, 4, 3, 50);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == @as(u32, @bitCast(@as(i32, -25))));
    try expect(cpu.cpsr[31] == 1);
    try expect(cpu.cpsr[29] == 0);
}

test "RSB - Reverse Subtract" {
    var cpu = Cpu.init();

    cpu.r[2] = 30;
    const instr = makeDataProcImm(0b1110, 0b0011, 0, 2, 1, 100);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 70);

    cpu.r[4] = 50;
    const instr_s = makeDataProcImm(0b1110, 0b0011, 1, 4, 3, 10);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == @as(u32, @bitCast(@as(i32, -40))));
    try expect(cpu.cpsr[31] == 1);
}

test "ADD - Add" {
    var cpu = Cpu.init();

    cpu.r[2] = 100;
    const instr = makeDataProcImm(0b1110, 0b0100, 0, 2, 1, 50);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 150);

    cpu.r[4] = 0xFFFFFF00;
    const instr_s = makeDataProcImm(0b1110, 0b0100, 1, 4, 3, 0xFF);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0xFFFFFFFF);
    try expect(cpu.cpsr[31] == 1);
    try expect(cpu.cpsr[30] == 0);
}

test "ADC - Add with Carry" {
    var cpu = Cpu.init();

    cpu.r[2] = 100;
    cpu.cpsr[29] = 0;
    const instr = makeDataProcImm(0b1110, 0b0101, 0, 2, 1, 10);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 110);

    cpu.r[4] = 100;
    cpu.cpsr[29] = 1;
    const instr2 = makeDataProcImm(0b1110, 0b0101, 0, 4, 3, 10);
    cpu.decode_execute(instr2);
    try expect(cpu.r[3] == 111);
}

test "SBC - Subtract with Carry" {
    var cpu = Cpu.init();

    cpu.r[2] = 100;
    cpu.cpsr[29] = 1;
    const instr = makeDataProcImm(0b1110, 0b0110, 0, 2, 1, 10);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 90);

    cpu.r[4] = 100;
    cpu.cpsr[29] = 0;
    const instr2 = makeDataProcImm(0b1110, 0b0110, 0, 4, 3, 10);
    cpu.decode_execute(instr2);
    try expect(cpu.r[3] == 89);
}

test "RSC - Reverse Subtract with Carry" {
    var cpu = Cpu.init();

    cpu.r[2] = 30;
    cpu.cpsr[29] = 1;
    const instr = makeDataProcImm(0b1110, 0b0111, 0, 2, 1, 100);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 70);

    cpu.r[4] = 30;
    cpu.cpsr[29] = 0;
    const instr2 = makeDataProcImm(0b1110, 0b0111, 0, 4, 3, 100);
    cpu.decode_execute(instr2);
    try expect(cpu.r[3] == 69);
}

test "TST - Test" {
    var cpu = Cpu.init();

    cpu.r[2] = 0xF0;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1110, 0b1000, 1, 2, 5, 0x0F);
    cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF);
    try expect(cpu.cpsr[30] == 1);

    cpu.r[3] = 0xFF;
    const instr2 = makeDataProcImm(0b1110, 0b1000, 1, 3, 0, 0x0F);
    cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 0);
}

test "TEQ - Test Equivalence" {
    var cpu = Cpu.init();

    cpu.r[2] = 0xFF;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1110, 0b1001, 1, 2, 5, 0xFF);
    cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF);
    try expect(cpu.cpsr[30] == 1);

    cpu.r[3] = 0xF0;
    const instr2 = makeDataProcImm(0b1110, 0b1001, 1, 3, 0, 0x0F);
    cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 0);
}

test "CMP - Compare" {
    var cpu = Cpu.init();

    cpu.r[2] = 100;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1110, 0b1010, 1, 2, 5, 50);
    cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF);
    try expect(cpu.cpsr[30] == 0);
    try expect(cpu.cpsr[29] == 1);
    try expect(cpu.cpsr[31] == 0);

    cpu.r[3] = 75;
    const instr2 = makeDataProcImm(0b1110, 0b1010, 1, 3, 0, 75);
    cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 1);
    try expect(cpu.cpsr[29] == 1);

    cpu.r[4] = 25;
    const instr3 = makeDataProcImm(0b1110, 0b1010, 1, 4, 0, 100);
    cpu.decode_execute(instr3);
    try expect(cpu.cpsr[31] == 1);
    try expect(cpu.cpsr[29] == 0);
}

test "CMN - Compare Negative" {
    var cpu = Cpu.init();

    cpu.r[2] = 100;
    cpu.r[5] = 0xDEADBEEF;
    const instr = makeDataProcImm(0b1110, 0b1011, 1, 2, 5, 50);
    cpu.decode_execute(instr);
    try expect(cpu.r[5] == 0xDEADBEEF);
    try expect(cpu.cpsr[30] == 0);

    cpu.r[3] = @as(u32, @bitCast(@as(i32, -100)));
    const instr2 = makeDataProcImm(0b1110, 0b1011, 1, 3, 0, 100);
    cpu.decode_execute(instr2);
    try expect(cpu.cpsr[30] == 1);
}

test "ORR - Bitwise OR" {
    var cpu = Cpu.init();

    cpu.r[2] = 0xF0;
    const instr = makeDataProcImm(0b1110, 0b1100, 0, 2, 1, 0x0F);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    cpu.r[4] = 0x00;
    const instr_s = makeDataProcImm(0b1110, 0b1100, 1, 4, 3, 0x00);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1);
}

test "MOV - Move" {
    var cpu = Cpu.init();

    const instr = makeDataProcImm(0b1110, 0b1101, 0, 0, 1, 0xFF);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    const instr_s = makeDataProcImm(0b1110, 0b1101, 1, 0, 2, 0x00);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[2] == 0x00);
    try expect(cpu.cpsr[30] == 1);
}

test "BIC - Bitwise Bit Clear" {
    var cpu = Cpu.init();

    cpu.r[2] = 0xFF;
    const instr = makeDataProcImm(0b1110, 0b1110, 0, 2, 1, 0x0F);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xF0);

    cpu.r[4] = 0xFF;
    const instr_s = makeDataProcImm(0b1110, 0b1110, 1, 4, 3, 0xFF);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[3] == 0x00);
    try expect(cpu.cpsr[30] == 1);
}

test "MVN - Bitwise NOT" {
    var cpu = Cpu.init();

    const instr = makeDataProcImm(0b1110, 0b1111, 0, 0, 1, 0x00);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFFFFFFFF);

    const instr_s = makeDataProcImm(0b1110, 0b1111, 1, 0, 2, 0xFF);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[2] == 0xFFFFFF00);
    try expect(cpu.cpsr[31] == 1);
    try expect(cpu.cpsr[30] == 0);
}

// You can add ADR tests similarly by encoding Rn=PC (15) and proper opcode.
