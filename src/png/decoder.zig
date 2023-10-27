const std = @import("std");
const models = @import("./models.zig");
const zlib = @cImport(@cInclude("zlib.h"));
const unfliter = @import("./unfilter.zig");

pub fn pngDecoder() type {
    return struct {
        const Self = @This();
        idat_allocator: std.mem.Allocator,
        unfiltered_list: std.ArrayList(u8),

        original_img_buffer: []u8,
        IHDR: models.IHDR,
        pHYS: ?models.pHYs = null,
        bKGD: ?models.bKGD = null,
        sRGB: ?models.sRGB = null,
        file_size: u64 = 0,

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
            const unfilter_allocator = std.heap.GeneralPurposeAllocator(.{}){};
            const unfilter_list = std.ArrayList(u8).init(unfilter_allocator.backing_allocator);
            return Self{
                .idat_allocator = idatAllocator,
                .unfiltered_list = unfilter_list,
                .original_img_buffer = buffer,
                .IHDR = .{
                    .height = height,
                    .width = width,
                    .bit_depth = bit_depth,
                    .color_type = color_type,
                    .compression_method = compression_method,
                    .filter_method = filter_method,
                    .interlace_method = interlace_method,
                },
                // .pHYS = .{

                // }
                .file_size = file_size,
            };
        }

        pub fn readChunks(self: *Self) !void {

            // bit 33 is one index after the last CRC byte for the IHDR.
            // start there
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
                // pHYs
                0b01110000_01001000_01011001_01110011 => self.handlepHYs(offset + 8),
                // bKGD
                0b01100010_01001011_01000111_01000100 => self.handlebKGD(offset + 8),
                // sRGB
                0b01110011_01010010_01000111_01000010 => self.handlesRGB(offset + 8),
                // gAMA
                0b01100111_01000001_01001101_01000001 => self.handlegAMA(offset + 8),
                // TODO: IEND
                // 0b01001001_01000101_01001110_01000100 => self.handleIEND(offset + 8, data_length),

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
            std.debug.print("idat hit\n", .{});

            var bytes_per_pix: u8 = switch (self.IHDR.color_type) {
                // match values represent color type
                // https://www.w3.org/TR/png/#3colourType
                // 1 byte: greyscale luminance
                0 => 1,
                // 3 bytes: R,G,B
                2 => 3,
                // 1 byte: pallete index
                3 => 1,
                // 2 bytes: greyscale luminance + Alpha
                4 => 2,
                // 4 bytes: R,G,B,A
                6 => 4,

                else => return,
            };

            const compressed_buf = self.original_img_buffer[data_offset..data_length];
            var uncompressed_len: c_ulong = ((self.IHDR.height * self.IHDR.width) * bytes_per_pix) + self.IHDR.height;
            var uncompressed_buf = try self.idat_allocator.alloc(u8, uncompressed_len);

            _ = zlib.uncompress(uncompressed_buf.ptr, &uncompressed_len, compressed_buf.ptr, data_length);
            _ = try self.unFilterIDAT(uncompressed_buf, bytes_per_pix);
            // for (uncompressed_buf, 0..) |value, i| {
            //     std.debug.print("val at {d} is {any}\n", .{ i, value });
            // }
        }

        fn unFilterIDAT(self: *Self, idat_buffer: []u8, bytes_per_pix: u8) !void {
            const line_width = (self.IHDR.width * bytes_per_pix) + 1;
            for (0..self.IHDR.height) |i| {
                // handle filter types 1 through 4
                switch (idat_buffer[i * line_width]) {
                    1 => unfliter.unFilterSub(idat_buffer, i, line_width, bytes_per_pix),
                    2 => unfliter.unFilterUp(),
                    3 => unfliter.unFilterAverage(),
                    4 => unfliter.unFilterPaeth(),
                    // filter was 0, don't do anything
                    else => {},
                }
                // _ = try self.unfiltered_list.appendSlice(idat_buffer[pos..line_width]);

            }
        }

        fn handlepHYs(self: *Self, offset: u32) void {
            const ppu_x: u32 =
                @as(u32, self.original_img_buffer[offset]) << 24 |
                @as(u32, self.original_img_buffer[offset + 1]) << 16 |
                @as(u32, self.original_img_buffer[offset + 2]) << 8 |
                @as(u32, self.original_img_buffer[offset + 3]);
            const ppu_y: u32 =
                @as(u32, self.original_img_buffer[offset + 4]) << 24 |
                @as(u32, self.original_img_buffer[offset + 5]) << 16 |
                @as(u32, self.original_img_buffer[offset + 6]) << 8 |
                @as(u32, self.original_img_buffer[offset + 7]);
            self.pHYS = .{
                .ppu_x = ppu_x,
                .ppu_y = ppu_y,
                .unit_specifier = self.original_img_buffer[offset + 9],
            };
        }

        fn handlebKGD(self: *Self, offset: u32) void {
            const greyscale: u16 =
                @as(u16, self.original_img_buffer[offset]) << 8 |
                @as(u16, self.original_img_buffer[offset + 1]);
            const red: u16 =
                @as(u16, self.original_img_buffer[offset + 2]) << 8 |
                @as(u16, self.original_img_buffer[offset + 3]);
            const green: u16 =
                @as(u16, self.original_img_buffer[offset + 4]) << 8 |
                @as(u16, self.original_img_buffer[offset + 5]);
            const blue: u16 =
                @as(u16, self.original_img_buffer[offset + 6]) << 8 |
                @as(u16, self.original_img_buffer[offset + 7]);

            self.bKGD = .{
                .greyscale = greyscale,
                .red = red,
                .green = green,
                .blue = blue,
                .palette_index = self.original_img_buffer[offset + 8],
            };
        }

        fn handlesRGB(self: *Self, offset: u32) void {
            self.sRGB = .{
                .rendering_intent = self.original_img_buffer[offset],
            };
        }

        // TODO: decode gAMA
        fn handlegAMA(self: *Self, offset: u32) void {
            const gama: u32 =
                @as(u32, self.original_img_buffer[offset]) << 24 |
                @as(u32, self.original_img_buffer[offset + 1]) << 16 |
                @as(u32, self.original_img_buffer[offset + 2]) << 8 |
                @as(u32, self.original_img_buffer[offset + 3]);
            std.debug.print("gama: {any}\n", .{gama});
        }

        pub fn print(self: *Self) void {
            std.debug.print("width {any}\n", .{self.IHDR.width});
            std.debug.print("height {any}\n", .{self.IHDR.height});
            std.debug.print("filter method {any}\n", .{self.IHDR.filter_method});
            // std.debug.print("bit_depth {any}\n", .{self.IHDR.bit_depth});
            std.debug.print("color_type {any}\n", .{self.IHDR.color_type});
            // std.debug.print("compression_method {any}\n", .{self.IHDR.compression_method});
            // std.debug.print("greyscale: {any}\n", .{self.bKGD.?.greyscale});
            // std.debug.print("red: {any}\n", .{self.bKGD.?.red});
            // std.debug.print("green: {any}\n", .{self.bKGD.?.green});
            // std.debug.print("blue: {any}\n", .{self.bKGD.?.blue});
            // std.debug.print("palette_index: {any}\n", .{self.bKGD.?.palette_index});
            // std.debug.print("rendering_intent: {any}\n", .{self.sRGB.?.rendering_intent});

        }
    };
}
