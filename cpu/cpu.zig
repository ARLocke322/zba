const std = @import("std");
const decoder = @import("decoder.zig");
const data_processing = @import("execute/data_processing.zig");
const load_store = @import("execute/load_store.zig");
const flags = @import("flags.zig");
const helpers = @import("helpers.zig");
const Memory = @import("../memory/memory.zig").Memory;

pub const Cpu = struct {
    r: [16]u32,
    cpsr: [32]u1,
    mem: *Memory,

    pub fn init(mem: *Memory) Cpu {
        return Cpu{
            .r = [_]u32{0} ** 16,
            .cpsr = [_]u1{0} ** 32,
            .mem = mem,
        };
    }

    pub fn decode_execute(self: *Cpu, instruction: u32) void {
        decoder.decode_execute(self, instruction);
    }

    pub fn read_data(self: *Cpu, address: u32, size: u6) u32 {
        return switch (size) {
            0x20 => self.mem.read32(address),
            0x10 => @as(u32, self.mem.read16(address)),
            0x8 => @as(u32, self.mem.read8(address)),
            else => unreachable,
        };
    }

    pub fn write_data(self: *Cpu, data: u32, address: u32, size: u6) void {
        switch (size) {
            0x20 => self.mem.write32(address, data),
            0x10 => self.mem.write16(address, @truncate(data)),
            0x8 => self.mem.write8(address, @truncate(data)),
            else => {},
        }
    }
};
