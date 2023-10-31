const std = @import("std");
const models = @import("./models.zig");
const unfliter = @import("./unfilter.zig");
const zlib = @cImport(@cInclude("zlib.h"));

pub fn pngDecoder() type {
    return struct {
        const Self = @This();
        // holds the compressed idat data
        idat_list: std.ArrayList(u8),
        idat_allocator: std.mem.Allocator,
        uncompressed_allocator: std.mem.Allocator,
        uncompressed_buf: []u8,

        uncompressed_len: c_ulong,
        bytes_per_pix: u8,
        original_img_buffer: []u8,

        IHDR: models.IHDR,
        pHYS: ?models.pHYs = null,
        bKGD: ?models.bKGD = null,
        sRGB: ?models.sRGB = null,
        file_size: u64 = 0,

        /// initialize the list allocator to store IDAT chunks and the buffer holding the read image file
        ///
        /// also fill in some metadata from the IHDR chunk
        pub fn init(idatAllocator: std.mem.Allocator, uncompressedAllocator: std.mem.Allocator, buffer: []u8, file_size: u64) !Self {
            var idat_list = std.ArrayList(u8).init(
                idatAllocator,
            );

            return Self{
                .idat_list = idat_list,
                .original_img_buffer = buffer,
                .idat_allocator = idatAllocator,
                .uncompressed_buf = undefined,
                .uncompressed_allocator = uncompressedAllocator,
                .uncompressed_len = undefined,
                .bytes_per_pix = undefined,
                .IHDR = undefined,
                .file_size = file_size,
            };
        }

        pub fn readChunks(self: *Self) !void {

            // byte 33 is one index after the last CRC byte for the IHDR.
            // start there
            var offset: u32 = 8;

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

            var crc = zlib.crc32(0, zlib.Z_NULL, 0);
            self.handleCRC(&crc, offset + 4, data_length);

            switch (data_type) {
                //IHDR
                0b01001001_01001000_01000100_01010010 => try self.handleIHDR(),
                // IDAT
                0b01001001_01000100_01000001_01010100 => try self.handleIDAT(offset + 8, data_length),
                // pHYs
                0b01110000_01001000_01011001_01110011 => self.handlepHYs(offset + 8),
                // bKGD
                0b01100010_01001011_01000111_01000100 => self.handlebKGD(offset + 8),
                // sRGB
                0b01110011_01010010_01000111_01000010 => self.handlesRGB(offset + 8),
                // gAMA
                0b01100111_01000001_01001101_01000001 => self.handlegAMA(offset + 8),
                // IEND
                0b01001001_01000101_01001110_01000100 => try self.unFilterIDAT(self.uncompressed_buf, self.bytes_per_pix),
                // char char char char
                else => std.debug.print("unhandled chunk {c}{c}{c}{c}\n", .{
                    self.original_img_buffer[offset + 4],
                    self.original_img_buffer[offset + 5],
                    self.original_img_buffer[offset + 6],
                    self.original_img_buffer[offset + 7],
                }),
            }

            // 4 byte length + 4 byte type + {{data_length}} data + 4 byte crc
            return data_length + 12;
        }

        fn handleIHDR(self: *Self) !void {
            const width: u32 =
                @as(u32, self.original_img_buffer[16]) << 24 |
                @as(u32, self.original_img_buffer[17]) << 16 |
                @as(u32, self.original_img_buffer[18]) << 8 |
                @as(u32, self.original_img_buffer[19]);
            const height: u32 =
                @as(u32, self.original_img_buffer[20]) << 24 |
                @as(u32, self.original_img_buffer[21]) << 16 |
                @as(u32, self.original_img_buffer[22]) << 8 |
                @as(u32, self.original_img_buffer[23]);

            const bit_depth: u8 = self.original_img_buffer[24];
            const color_type: u8 = self.original_img_buffer[25];
            const compression_method: u8 = self.original_img_buffer[26];
            const filter_method: u8 = self.original_img_buffer[27];
            const interlace_method: u8 = self.original_img_buffer[28];

            var bytes_per_pix: u8 = switch (color_type) {
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

                else => unreachable,
            };

            var uncompressed_len: c_ulong = ((height * width) * bytes_per_pix) + height;
            var uncompressed_buf = try self.uncompressed_allocator.alloc(u8, uncompressed_len);
            self.uncompressed_buf = uncompressed_buf;
            self.uncompressed_len = uncompressed_len;

            self.IHDR = .{
                .height = height,
                .width = width,
                .bit_depth = bit_depth,
                .color_type = color_type,
                .compression_method = compression_method,
                .filter_method = filter_method,
                .interlace_method = interlace_method,
            };
            self.bytes_per_pix = bytes_per_pix;
        }

        fn handleCRC(self: *Self, crc: *c_ulong, type_offset: u32, data_length: u32) void {
            var end_pos = type_offset + data_length + 4;
            const buffer = self.original_img_buffer[type_offset..end_pos];
            crc.* = zlib.crc32(crc.*, buffer.ptr, data_length + 4);
            const original_crc: u32 =
                @as(u32, self.original_img_buffer[end_pos]) << 24 |
                @as(u32, self.original_img_buffer[end_pos + 1]) << 16 |
                @as(u32, self.original_img_buffer[end_pos + 2]) << 8 |
                @as(u32, self.original_img_buffer[end_pos + 3]);

            std.debug.print("chunk {c}{c}{c}{c}\n", .{
                self.original_img_buffer[type_offset],
                self.original_img_buffer[type_offset + 1],
                self.original_img_buffer[type_offset + 2],
                self.original_img_buffer[type_offset + 3],
            });
            if (crc.* == original_crc) {
                std.debug.print("crc values identical\n\n", .{});
            } else {
                std.debug.print("crc values differ\n\n", .{});
            }
        }

        // appends an entire IDAT chunk to the idat list
        fn handleIDAT(self: *Self, data_offset: u32, data_length: u32) !void {
            var end_pos = data_offset + data_length;
            const compressed_buf = self.original_img_buffer[data_offset..end_pos];
            _ = try self.idat_list.appendSlice(compressed_buf);
        }

        fn unFilterIDAT(self: *Self, idat_buffer: []u8, bytes_per_pix: u8) !void {
            // std.debug.print("unfilter called\n", .{});
            _ = zlib.uncompress(self.uncompressed_buf.ptr, &self.uncompressed_len, self.idat_list.items.ptr, self.idat_list.items.len);
            const line_width = (self.IHDR.width * bytes_per_pix) + 1;
            for (0..self.IHDR.height) |i| {
                // handle filter types 1 through 4
                switch (idat_buffer[i * line_width]) {
                    1 => unfliter.unFilterSub(idat_buffer, i, line_width, bytes_per_pix),
                    2 => unfliter.unFilterUp(idat_buffer, i, line_width, bytes_per_pix),
                    3 => unfliter.unFilterAverage(idat_buffer, i, line_width, bytes_per_pix),
                    4 => unfliter.unFilterPaeth(idat_buffer, i, line_width, bytes_per_pix),
                    // filter was 0, don't do anything
                    else => {},
                }
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
            _ = self;
            // std.debug.print("width {any}\n", .{self.IHDR.width});
            // std.debug.print("height {any}\n", .{self.IHDR.height});
            // std.debug.print("filter method {any}\n", .{self.IHDR.filter_method});
            // std.debug.print("bit_depth {any}\n", .{self.IHDR.bit_depth});
            // std.debug.print("color_type {any}\n", .{self.IHDR.color_type});
            // std.debug.print("compression_method {any}\n", .{self.IHDR.compression_method});
            // std.debug.print("greyscale: {any}\n", .{self.bKGD.?.greyscale});
            // std.debug.print("red: {any}\n", .{self.bKGD.?.red});
            // std.debug.print("green: {any}\n", .{self.bKGD.?.green});
            // std.debug.print("blue: {any}\n", .{self.bKGD.?.blue});
            // std.debug.print("palette_index: {any}\n", .{self.bKGD.?.palette_index});
            // std.debug.print("rendering_intent: {any}\n", .{self.sRGB.?.rendering_intent});
            // for (0..self.uncompressed_len) |i| {
            //     std.debug.print("val at {d}: {any}\n", .{ i, self.uncompressed_buf[i] });
            // }
            // std.debug.print("idat_list.len after: {any}\n\n", .{self.idat_list.items.len});
        }
    };
}
