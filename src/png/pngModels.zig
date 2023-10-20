// http://www.libpng.org/pub/png/spec/iso/index-object.html
const std = @import("std");

// pub const ChunkType = enum(u32) {
//     IHDR = 0b01001001_01001000_01000100_01010010,
//     PLTE = 0b01010000_01001100_01010100_01000101,
//     IDAT = 0b01001001_01000100_01000001_01010100,
//     IEND = 0b01001001_01000101_01001110_01000100,
// };

// // not too different from simple union
// pub const chunkUnion = union(ChunkType) {
//     IHDR: IHDRs,
//     PLTE: PLTEs,
// };

// Chunks
pub const IHDR = struct {
    width: u32,
    height: u32,
    bit_depth: u8,
    color_type: u8,
    compression_method: u8,
    filter_method: u8,
    interlace_method: u8,
};

pub const pHYs = struct {
    ppu_x: u32,
    ppu_y: u32,
    unit_specifier: u8,
};

pub const bKGD = struct {
    greyscale: u16,
    red: u16,
    green: u16,
    blue: u16,
    palette_index: u8,
};

pub const sRGB = struct {
    rendering_intent: u8,
};

pub const PLTEs = struct {
    red: u8,
    green: u8,
    blue: u8,
};
