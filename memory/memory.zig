const std = @import("std");

pub const Memory = struct {
    bios: [16 * 1024]u8,
    ewram: [256 * 1024]u8,
    iwram: [32 * 1024]u8,
    io: [1024]u8,
    palette: [1024]u8,
    vram: [96 * 1024]u8,
    oam: [1024]u8,
    // rom

    pub fn init() Memory {
        return Memory{
            .bios = [_]u8{0} ** (16 * 1024),
            .ewram = [_]u8{0} ** (256 * 1024),
            .iwram = [_]u8{0} ** (32 * 1024),
            .io = [_]u8{0} ** (1024),
            .palette = [_]u8{0} ** (1024),
            .vram = [_]u8{0} ** (96 * 1024),
            .oam = [_]u8{0} ** (1024),
        };
    }

    pub fn read8(self: *Memory, address: u32) u8 {
        return switch (address) {
            0x00000000...0x00003FFF => self.bios[address],
            0x02000000...0x0203FFFF => self.ewram[address - 0x02000000],
            0x03000000...0x03007FFF => self.iwram[address - 0x03000000],
            0x04000000...0x040003FF => self.io[address - 0x04000000],
            0x05000000...0x050003FF => self.palette[address - 0x05000000],
            0x06000000...0x06017FFF => self.vram[address - 0x06000000],
            0x07000000...0x070003FF => self.oam[address - 0x07000000],
            // 0x08000000...0x0DFFFFFF => self.rom[address - 0x08000000],
            else => 0,
        };
    }

    pub fn write8(self: *Memory, address: u32, value: u8) void {
        switch (address) {
            0x02000000...0x0203FFFF => self.ewram[address - 0x02000000] = value,
            0x03000000...0x03007FFF => self.iwram[address - 0x03000000] = value,
            0x04000000...0x040003FF => self.io[address - 0x04000000] = value,
            0x05000000...0x050003FF => self.palette[address - 0x05000000] = value,
            0x06000000...0x06017FFF => self.vram[address - 0x06000000] = value,
            0x07000000...0x070003FF => self.oam[address - 0x07000000] = value,
            else => {},
        }
    }
    pub fn read16(self: *Memory, address: u32) u16 {
        const b0 = self.read8(address);
        const b1 = self.read8(address + 1);
        return @as(u16, b1) << 8 | b0;
    }

    pub fn write16(self: *Memory, address: u32, value: u16) void {
        self.write8(address, @truncate(value));
        self.write8(address + 1, @truncate(value >> 8));
    }

    pub fn read32(self: *Memory, address: u32) u32 {
        const b0 = self.read8(address);
        const b1 = self.read8(address + 1);
        const b2 = self.read8(address + 2);
        const b3 = self.read8(address + 3);
        return @as(u32, b3) << 24 | @as(u32, b2) << 16 | @as(u32, b1) << 8 | b0;
    }

    pub fn write32(self: *Memory, address: u32, value: u32) void {
        self.write8(address, @truncate(value));
        self.write8(address + 1, @truncate(value >> 8));
        self.write8(address + 2, @truncate(value >> 16));
        self.write8(address + 3, @truncate(value >> 24));
    }
};
