const std = @import("std");
const Cpu = @import("../cpu.zig").Cpu;

pub fn execute_LDR(
    cpu: *Cpu,
    r_n: u4,
    r_t: u4,
    imm: u12,
    register: bool,
    pre_indexed: bool,
    writeback: bool,
    add_offset: bool,
    size: u6,
) void {
    // NOTE: imm5 == 0 special cases (LSR/ASR/RRX) not yet implemented p290
    @setRuntimeSafety(false);
    var offset: u32 = undefined;
    if (register) {
        const imm5: u5 = @truncate(imm >> 7);
        const shift_type: u2 = @truncate(imm >> 5);
        const r_m: u4 = @truncate(imm);

        offset = switch (shift_type) {
            0x00 => cpu.r[r_m] << imm5,
            0x01 => cpu.r[r_m] >> imm5,
            0x02 => @bitCast(@as(i32, @bitCast(cpu.r[r_m])) >> imm5),
            0x03 => std.math.rotr(u32, cpu.r[r_m], imm5),
        };
    } else offset = imm;

    const original_address = cpu.r[r_n];
    const indexed_address = if (add_offset) cpu.r[r_n] + offset else cpu.r[r_n] - offset;

    if (writeback) cpu.r[r_n] = indexed_address;

    if (pre_indexed) {
        cpu.r[r_t] = cpu.read_data(indexed_address, size);
    } else {
        cpu.r[r_t] = cpu.read_data(original_address, size);
    }
}

pub fn execute_STR(
    cpu: *Cpu,
    r_n: u4,
    r_t: u4,
    imm: u12,
    register: bool,
    pre_indexed: bool,
    writeback: bool,
    add_offset: bool,
    size: u6,
) void {
    @setRuntimeSafety(false);
    var offset: u32 = undefined;
    if (register) {
        const imm5: u5 = @truncate(imm >> 7);
        const shift_type: u2 = @truncate(imm >> 5);
        const r_m: u4 = @truncate(imm);

        offset = switch (shift_type) {
            0x00 => cpu.r[r_m] << imm5,
            0x01 => cpu.r[r_m] >> imm5,
            0x02 => @bitCast(@as(i32, @bitCast(cpu.r[r_m])) >> imm5),
            0x03 => std.math.rotr(u32, cpu.r[r_m], imm5),
        };
    } else offset = imm;

    const original_address = cpu.r[r_n];
    const indexed_address = if (add_offset) cpu.r[r_n] + offset else cpu.r[r_n] - offset;

    if (writeback) cpu.r[r_n] = indexed_address;

    if (pre_indexed) {
        cpu.write_data(cpu.r[r_t], indexed_address, size);
    } else {
        cpu.write_data(cpu.r[r_t], original_address, size);
    }
}
