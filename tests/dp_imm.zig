const std = @import("std");
const expect = std.testing.expect;
const Cpu = @import("../cpu/cpu.zig").Cpu;
const Memory = @import("../memory/memory.zig").Memory;

// --- HELPER FUNCTION TO BUILD FULL 32-BIT DATA-PROCESSING IMMEDIATE INSTRUCTION ---
fn makeDataProcImm(
    cond: u4,
    op: u4,
    s: u1,
    rn: u4,
    rd: u4,
    imm12: u12,
) u32 {
    var instr: u32 = 0;
    instr |= @as(u32, cond) << 28;
    instr |= 0b001 << 25;
    instr |= @as(u32, op) << 21;
    instr |= @as(u32, s) << 20;
    instr |= @as(u32, rn) << 16;
    instr |= @as(u32, rd) << 12;
    instr |= @as(u32, imm12);
    return instr;
}

// --- HELPER FUNCTION TO BUILD LOAD/STORE IMMEDIATE INSTRUCTION ---
fn makeLoadStoreImm(
    cond: u4, // bits 31-28
    p: u1, // bit 24 (pre/post indexed)
    u: u1, // bit 23 (add/subtract offset)
    b: u1, // bit 22 (byte/word)
    w: u1, // bit 21 (writeback)
    l: u1, // bit 20 (load/store)
    rn: u4, // bits 19-16 (base register)
    rt: u4, // bits 15-12 (source/dest register)
    imm12: u12, // bits 11-0 (immediate offset)
) u32 {
    var instr: u32 = 0;
    instr |= @as(u32, cond) << 28;
    instr |= 0b01 << 26; // Load/Store Word/Byte encoding
    instr |= @as(u32, p) << 24;
    instr |= @as(u32, u) << 23;
    instr |= @as(u32, b) << 22;
    instr |= @as(u32, w) << 21;
    instr |= @as(u32, l) << 20;
    instr |= @as(u32, rn) << 16;
    instr |= @as(u32, rt) << 12;
    instr |= @as(u32, imm12);
    return instr;
}

// --- HELPER FUNCTION TO BUILD LOAD/STORE REGISTER INSTRUCTION ---
fn makeLoadStoreReg(
    cond: u4,
    p: u1,
    u: u1,
    b: u1,
    w: u1,
    l: u1,
    rn: u4,
    rt: u4,
    imm5: u5, // shift amount
    shift_type: u2, // 00=LSL, 01=LSR, 10=ASR, 11=ROR
    rm: u4, // offset register
) u32 {
    var instr: u32 = 0;
    instr |= @as(u32, cond) << 28;
    instr |= 0b011 << 25; // Register offset encoding
    instr |= @as(u32, p) << 24;
    instr |= @as(u32, u) << 23;
    instr |= @as(u32, b) << 22;
    instr |= @as(u32, w) << 21;
    instr |= @as(u32, l) << 20;
    instr |= @as(u32, rn) << 16;
    instr |= @as(u32, rt) << 12;
    instr |= @as(u32, imm5) << 7;
    instr |= @as(u32, shift_type) << 5;
    instr |= @as(u32, rm);
    return instr;
}

// --- DATA PROCESSING TESTS (existing tests remain the same) ---

test "AND - Bitwise AND" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    const instr = makeDataProcImm(0b1110, 0b1101, 0, 0, 1, 0xFF);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFF);

    const instr_s = makeDataProcImm(0b1110, 0b1101, 1, 0, 2, 0x00);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[2] == 0x00);
    try expect(cpu.cpsr[30] == 1);
}

test "BIC - Bitwise Bit Clear" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

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
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    const instr = makeDataProcImm(0b1110, 0b1111, 0, 0, 1, 0x00);
    cpu.decode_execute(instr);
    try expect(cpu.r[1] == 0xFFFFFFFF);

    const instr_s = makeDataProcImm(0b1110, 0b1111, 1, 0, 2, 0xFF);
    cpu.decode_execute(instr_s);
    try expect(cpu.r[2] == 0xFFFFFF00);
    try expect(cpu.cpsr[31] == 1);
    try expect(cpu.cpsr[30] == 0);
}

// --- LOAD/STORE TESTS ---

test "STR - Store Word, Immediate Offset, Pre-indexed" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0xDEADBEEF; // value to store
    cpu.r[2] = 0x03000000; // base address (IWRAM)

    // STR R1, [R2, #8]! - pre-indexed with writeback
    const instr = makeLoadStoreImm(0b1110, 1, 1, 0, 1, 0, 2, 1, 8);
    cpu.decode_execute(instr);

    try expect(cpu.mem.read32(0x03000008) == 0xDEADBEEF);
    try expect(cpu.r[2] == 0x03000008); // writeback occurred
}

test "LDR - Load Word, Immediate Offset, Pre-indexed" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    // Set up memory with test value
    cpu.mem.write32(0x03000010, 0x12345678);
    cpu.r[2] = 0x03000000; // base address

    // LDR R1, [R2, #16]! - pre-indexed with writeback
    const instr = makeLoadStoreImm(0b1110, 1, 1, 0, 1, 1, 2, 1, 16);
    cpu.decode_execute(instr);

    try expect(cpu.r[1] == 0x12345678);
    try expect(cpu.r[2] == 0x03000010); // writeback occurred
}

test "STR - Store Word, Post-indexed" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0xCAFEBABE;
    cpu.r[2] = 0x03000020;

    // STR R1, [R2], #4 - post-indexed (p=0, w is don't care)
    const instr = makeLoadStoreImm(0b1110, 0, 1, 0, 0, 0, 2, 1, 4);
    cpu.decode_execute(instr);

    try expect(cpu.mem.read32(0x03000020) == 0xCAFEBABE); // stored at original address
    try expect(cpu.r[2] == 0x03000024); // base updated after
}

test "LDR - Load Word, Post-indexed" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.mem.write32(0x03000030, 0xABCDEF00);
    cpu.r[2] = 0x03000030;

    // LDR R1, [R2], #8 - post-indexed
    const instr = makeLoadStoreImm(0b1110, 0, 1, 0, 0, 1, 2, 1, 8);
    cpu.decode_execute(instr);

    try expect(cpu.r[1] == 0xABCDEF00);
    try expect(cpu.r[2] == 0x03000038); // base updated after
}

test "STRB - Store Byte" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0xDEADBEEF;
    cpu.r[2] = 0x03000040;

    // STRB R1, [R2, #4] - pre-indexed, no writeback
    const instr = makeLoadStoreImm(0b1110, 1, 1, 1, 0, 0, 2, 1, 4);
    cpu.decode_execute(instr);

    try expect(cpu.mem.read8(0x03000044) == 0xEF); // only low byte stored
    try expect(cpu.r[2] == 0x03000040); // no writeback (w=0)
}

test "LDRB - Load Byte" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.mem.write8(0x03000050, 0x42);
    cpu.r[2] = 0x03000050;

    // LDRB R1, [R2] - no offset, pre-indexed
    const instr = makeLoadStoreImm(0b1110, 1, 1, 1, 0, 1, 2, 1, 0);
    cpu.decode_execute(instr);

    try expect(cpu.r[1] == 0x42); // zero-extended to 32-bit
}

test "STR - Negative Offset" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0x11111111;
    cpu.r[2] = 0x03000100;

    // STR R1, [R2, #-12] - negative offset (u=0)
    const instr = makeLoadStoreImm(0b1110, 1, 0, 0, 0, 0, 2, 1, 12);
    cpu.decode_execute(instr);

    try expect(cpu.mem.read32(0x030000F4) == 0x11111111);
    try expect(cpu.r[2] == 0x03000100); // no writeback
}

test "LDR - Register Offset with LSL" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.mem.write32(0x03000010, 0x99887766); // Changed from 0x03000020 to 0x03000010
    cpu.r[2] = 0x03000000; // base
    cpu.r[3] = 4; // offset register (4 << 2 = 16)

    // LDR R1, [R2, R3, LSL #2] - register offset with shift
    const instr = makeLoadStoreReg(0b1110, 1, 1, 0, 0, 1, 2, 1, 2, 0b00, 3);
    cpu.decode_execute(instr);

    try expect(cpu.r[1] == 0x99887766); // loaded from 0x03000000 + (4<<2) = 0x03000010
}

test "STR - Register Offset with LSR" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0x55555555;
    cpu.r[2] = 0x03000000; // base
    cpu.r[3] = 128; // offset register (128 >> 2 = 32)

    // STR R1, [R2, R3, LSR #2] - register offset with logical shift right
    const instr = makeLoadStoreReg(0b1110, 1, 1, 0, 0, 0, 2, 1, 2, 0b01, 3);
    cpu.decode_execute(instr);

    try expect(cpu.mem.read32(0x03000020) == 0x55555555); // 0x03000000 + (128>>2) = 0x03000020
}

test "LDR - Register Offset with ASR" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.mem.write32(0x03000010, 0xFFEEDDCC); // Changed address
    cpu.r[2] = 0x03000000; // base
    cpu.r[3] = 64; // Changed to positive number: 64 >> 2 = 16

    // LDR R1, [R2, R3, ASR #2] - arithmetic shift right
    const instr = makeLoadStoreReg(0b1110, 1, 1, 0, 0, 1, 2, 1, 2, 0b10, 3);
    cpu.decode_execute(instr);

    try expect(cpu.r[1] == 0xFFEEDDCC); // loaded from 0x03000000 + (64>>2) = 0x03000010
}

test "STR - Register Offset with ROR" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0xAAAAAAAA;
    cpu.r[2] = 0x03000000; // base
    cpu.r[3] = 0x00000040; // 64

    // STR R1, [R2, R3, ROR #2] - rotate right
    const instr = makeLoadStoreReg(0b1110, 1, 1, 0, 0, 0, 2, 1, 2, 0b11, 3);
    cpu.decode_execute(instr);

    // 0x40 ROR 2 = 0x10 (16 decimal)
    try expect(cpu.mem.read32(0x03000010) == 0xAAAAAAAA);
}

test "LDR - Multiple Operations" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    // Set up a sequence of values in memory
    cpu.mem.write32(0x03000000, 0x11111111);
    cpu.mem.write32(0x03000004, 0x22222222);
    cpu.mem.write32(0x03000008, 0x33333333);

    cpu.r[5] = 0x03000000;

    // LDR R1, [R5], #4 - post-indexed
    const instr1 = makeLoadStoreImm(0b1110, 0, 1, 0, 0, 1, 5, 1, 4);
    cpu.decode_execute(instr1);
    try expect(cpu.r[1] == 0x11111111);
    try expect(cpu.r[5] == 0x03000004);

    // LDR R2, [R5], #4 - post-indexed again
    const instr2 = makeLoadStoreImm(0b1110, 0, 1, 0, 0, 1, 5, 2, 4);
    cpu.decode_execute(instr2);
    try expect(cpu.r[2] == 0x22222222);
    try expect(cpu.r[5] == 0x03000008);

    // LDR R3, [R5] - no offset
    const instr3 = makeLoadStoreImm(0b1110, 1, 1, 0, 0, 1, 5, 3, 0);
    cpu.decode_execute(instr3);
    try expect(cpu.r[3] == 0x33333333);
}

test "STR/LDR - Round Trip Test" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    const test_value: u32 = 0xDEADBEEF;
    const test_addr: u32 = 0x03000200;

    cpu.r[1] = test_value;
    cpu.r[2] = test_addr;

    // STR R1, [R2]
    const store_instr = makeLoadStoreImm(0b1110, 1, 1, 0, 0, 0, 2, 1, 0);
    cpu.decode_execute(store_instr);

    // Clear R1
    cpu.r[1] = 0;

    // LDR R1, [R2]
    const load_instr = makeLoadStoreImm(0b1110, 1, 1, 0, 0, 1, 2, 1, 0);
    cpu.decode_execute(load_instr);

    try expect(cpu.r[1] == test_value);
}

test "STRB/LDRB - Byte Round Trip Test" {
    var mem = Memory.init();
    var cpu = Cpu.init(&mem);

    cpu.r[1] = 0xDEADBEEF; // full word
    cpu.r[2] = 0x03000300;

    // STRB R1, [R2] - store only low byte
    const store_instr = makeLoadStoreImm(0b1110, 1, 1, 1, 0, 0, 2, 1, 0);
    cpu.decode_execute(store_instr);

    cpu.r[1] = 0; // clear

    // LDRB R1, [R2] - load byte (zero-extended)
    const load_instr = makeLoadStoreImm(0b1110, 1, 1, 1, 0, 1, 2, 1, 0);
    cpu.decode_execute(load_instr);

    try expect(cpu.r[1] == 0xEF); // only low byte
}
