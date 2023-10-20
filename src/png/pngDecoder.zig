const std = @import("std");
const pngModels = @import("./pngModels.zig");
const zlib = @cImport(@cInclude("zlib.h"));

const ChunkResponse = pngModels.ChunkReturn;

pub fn pngDecoder() type {
    return struct {
        const Self = @This();
        idat_allocator: std.mem.Allocator,

        original_img_buffer: []u8,
        width: u32 = 0,
        height: u32 = 0,
        file_size: u64 = 0,
        bit_depth: u8 = 0,
        color_type: u8 = 0,
        compression_method: u8 = 0,
        filter_method: u8 = 0,
        interlace_method: u8 = 0,

        /// initialize the list allocator to store IDAT chunks and the buffer holding the read image file
        ///
        /// also fill in some metadata from the IHDR chunk
        pub fn init(idatAllocator: std.mem.Allocator, buffer: []u8, file_size: u64) Self {
            const width: u32 =
                @as(u32, buffer[16]) << 24 |
                @as(u32, buffer[17]) << 16 |
                @as(u32, buffer[18]) << 8 |
                @as(u32, buffer[19]);
            const height: u32 =
                @as(u32, buffer[20]) << 24 |
                @as(u32, buffer[21]) << 16 |
                @as(u32, buffer[22]) << 8 |
                @as(u32, buffer[23]);

            const bit_depth: u8 = buffer[24];
            const color_type: u8 = buffer[25];
            const compression_method: u8 = buffer[26];
            const filter_method: u8 = buffer[27];
            const interlace_method: u8 = buffer[28];

            return Self{
                .idat_allocator = idatAllocator,
                .original_img_buffer = buffer,
                .height = height,
                .width = width,
                .bit_depth = bit_depth,
                .color_type = color_type,
                .compression_method = compression_method,
                .filter_method = filter_method,
                .interlace_method = interlace_method,
                .file_size = file_size,
            };
        }

        pub fn readChunks(self: *Self) !void {

            // bit 33 is one index after the last CRC byte for the IHDR
            var offset: u32 = 33;

            while (offset < self.file_size) {
                offset += try self.read_chunk(offset);
            }
        }

        fn read_chunk(self: *Self, offset: u32) !u32 {
            const data_length: u32 =
                @as(u32, self.original_img_buffer[offset]) << 24 |
                @as(u32, self.original_img_buffer[offset + 1]) << 16 |
                @as(u32, self.original_img_buffer[offset + 2]) << 8 |
                @as(u32, self.original_img_buffer[offset + 3]);

            const data_type: u32 =
                @as(u32, self.original_img_buffer[offset + 4]) << 24 |
                @as(u32, self.original_img_buffer[offset + 5]) << 16 |
                @as(u32, self.original_img_buffer[offset + 6]) << 8 |
                @as(u32, self.original_img_buffer[offset + 7]);

            switch (data_type) {
                // IDAT
                0b01001001_01000100_01000001_01010100 => try self.handleIDATuncompress(offset + 8, data_length),
                // TODO: pHYs
                // 0b11010100_01001011_01001000_01010101 => try self.handlePHYs(offset + 8, data_length),
                // TODO: sRGB
                //  0b11010100_01010011_01010011_01010100 => try self.handleSRGB(offset + 8, data_length),
                // TODO: gAMA
                // 0b11001010_01000001_01000001_01000111 => try self.handleGAMA(offset + 8, data_length),
                // TODO: IEND
                // 0b01001001_01000101_01001110_01000100 => try self.handleIEND(offset + 8, data_length),

                // char char char char
                else => std.debug.print("unhandled chunk {c}{c}{c}{c}\n", .{
                    self.original_img_buffer[offset + 4],
                    self.original_img_buffer[offset + 5],
                    self.original_img_buffer[offset + 6],
                    self.original_img_buffer[offset + 7],
                }),
            }
            // TODO: handle crc
            // const crc: u32 =
            //     @as(u32, self.original_img_buffer[offset + data_length + 8]) << 24 |
            //     @as(u32, self.original_img_buffer[offset + data_length + 9]) << 16 |
            //     @as(u32, self.original_img_buffer[offset + data_length + 10]) << 8 |
            //     @as(u32, self.original_img_buffer[offset + data_length + 11]);

            // 4 byte length + 4 byte type + [data_length] data + 4 byte crc
            return data_length + 12;
        }

        // appends an entire IDAT chunk to the idat list
        fn handleIDATuncompress(self: *Self, data_offset: u32, data_length: u32) !void {
            const data_buffer = self.original_img_buffer[data_offset..data_length];
            // TODO: handle other color types. currently hardcoding 4 to stand for color type 6 (R,G,B,A)
            var uncompressed_len: c_ulong = ((self.height * self.width) * 4) + self.height;
            var uncompressed_buf = try self.idat_allocator.alloc(u8, uncompressed_len);
            _ = zlib.uncompress(uncompressed_buf.ptr, &uncompressed_len, data_buffer.ptr, data_length);

            // for (uncompressed_buf, 0..) |val, i| {
            //     std.debug.print("val at {d}: {any}\n", .{ i, val });
            // }
        }

        pub fn print(self: *Self) void {
            std.debug.print("width {any}\n", .{self.width});
            std.debug.print("height {any}\n", .{self.height});
            std.debug.print("bit_depth {any}\n", .{self.bit_depth});
            std.debug.print("color_type {any}\n", .{self.color_type});
            std.debug.print("compression_method {any}\n", .{self.compression_method});
        }
    };
}
