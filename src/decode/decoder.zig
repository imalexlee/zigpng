const std = @import("std");
const chunks = @import("./chunks.zig");
const unfliter = @import("./unfilter.zig");
const zlib = @cImport(@cInclude("zlib.h"));

const PNG_SIGNATURE = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

const PNGReadError = error{
    NotPNG,
    CorruptedCRC,
    PLTENotDivisibleByThree,
};

/// defines whether or not to process the following
const DecoderConfig = struct {
    checksum: bool = true,
    pHYS: bool = false,
    bKGD: bool = false,
    sRGB: bool = false,
    sBIT: bool = false,
    gAMA: bool = false,
};

pub fn pngDecoder() type {
    return struct {
        const Self = @This();
        original_img_buffer: []u8,
        original_img_allocator: std.mem.Allocator,
        file_size: u64 = 0,

        // the starting index of the first idat chunk type
        idat_start: u32,
        idat_list: std.ArrayList(u8),
        idat_allocator: std.mem.Allocator,
        pixel_buf: []u8,
        uncompressed_allocator: std.mem.Allocator,
        //       palette_allocator: std.mem.Allocator,

        sample_size: u8,

        IHDR: chunks.IHDR,
        pHYS: ?chunks.pHYs = null,
        bKGD: ?chunks.bKGD = null,
        sRGB: ?chunks.sRGB = null,
        sBIT: ?chunks.sBIT = null,
        PLTE: ?chunks.PLTE = null,

        config: DecoderConfig,

        /// idat_allocator used by ArrayList to store a consecutive u8 slice made from all appended, uncompressed, IDAT chunk data
        ///
        /// uncompressed_allocator used by zlib to store just the decompressed IDAT chunk data with filter byte intact at scanline start
        pub fn init(idatAllocator: std.mem.Allocator, uncompressedAllocator: std.mem.Allocator, config: DecoderConfig) !Self {
            var idat_list = std.ArrayList(u8).init(
                idatAllocator,
            );

            //          var palette_gpa = std.heap.GeneralPurposeAllocator(.{}){};
            //          var p_alloc = palette_gpa.allocator();
            return Self{
                .idat_list = idat_list,
                .original_img_buffer = undefined,
                .original_img_allocator = undefined,
                .idat_allocator = idatAllocator,
                .pixel_buf = undefined,
                .uncompressed_allocator = uncompressedAllocator,
                .sample_size = undefined,
                .IHDR = undefined,
                .file_size = undefined,
                .idat_start = undefined,
                .config = config,
            };
        }

        /// Cannot reuse this decoder instance after this operation
        pub fn deinit(self: *Self) void {
            self.idat_list.deinit();
            self.original_img_allocator.free(self.original_img_buffer);
            self.uncompressed_allocator.free(self.pixel_buf);
            if (self.PLTE != null) self.uncompressed_allocator.free(self.PLTE.?.sections);
            self.* = undefined;
        }

        /// Resets the decoder to its original state while sill holding references to both allocator
        pub fn reset(self: *Self) void {
            self.original_img_allocator(self.original_img_allocator);
            self.original_img_buffer = undefined;
            self.idat_list.clearAndFree();
            self.uncompressed_allocator.free(self.pixel_buf);
            if (self.PLTE != null) self.uncompressed_allocator.free(self.PLTE.?.sections);

            self.file_size = undefined;
            self.pixel_buf = undefined;
            self.pHYS = null;
            self.bKGD = null;
            self.sRGB = null;
            self.sample_size = undefined;
            self.IHDR = undefined;
        }

        /// loads an image from a give path in the current working directory
        pub fn loadFileFromPath(self: *Self, allocator: std.mem.Allocator, file_path: []const u8, flags: std.fs.File.OpenFlags) !void {
            const file = try std.fs.cwd().openFile(file_path, flags);
            defer file.close();
            self.file_size = try file.getEndPos();
            self.original_img_buffer = try allocator.alloc(u8, self.file_size);
            _ = try file.read(self.original_img_buffer);
            self.original_img_allocator = allocator;
        }

        /// safe to close file after function executes
        pub fn loadFile(self: *Self, allocator: std.mem.Allocator, file: std.fs.File) !void {
            self.file_size = try file.getEndPos();
            self.original_img_buffer = try allocator.alloc(u8, self.file_size);
            _ = try file.read(self.original_img_buffer);
        }

        pub fn readInfo(self: *Self) !void {
            inline for (PNG_SIGNATURE, 0..) |value, i| {
                if (value != self.original_img_buffer[i]) {
                    return PNGReadError.NotPNG;
                }
            }

            // start after the PNG signature, at byte index 8
            var offset: u32 = 8;
            while (offset < self.file_size) {
                var temp: u32 = try self.readInfoChunk(offset);
                if (temp == 0) {
                    break;
                }
                offset += temp;
            }
            self.idat_start = offset;
        }

        fn readInfoChunk(self: *Self, offset: u32) !u32 {
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

            if (self.config.checksum) {
                // initialize CRC
                var crc = zlib.crc32(0, zlib.Z_NULL, 0);

                try self.handleCRC(&crc, offset + 4, data_length);
            }

            switch (data_type) {
                // IDAT
                0b01001001_01000100_01000001_01010100 => {
                    return 0;
                },
                //IHDR
                0b01001001_01001000_01000100_01010010 => try self.handleIHDR(),
                // PLTE
                0b01010000_01001100_01010100_01000101 => try self.handlePLTE(offset + 8, data_length),
                // pHYs
                0b01110000_01001000_01011001_01110011 => if (self.config.pHYS) self.handlepHYs(offset + 8),
                // bKGD
                0b01100010_01001011_01000111_01000100 => if (self.config.bKGD) self.handlebKGD(offset + 8),
                // sRGB
                0b01110011_01010010_01000111_01000010 => if (self.config.sRGB) self.handlesRGB(offset + 8),
                // gAMA
                0b01100111_01000001_01001101_01000001 => if (self.config.gAMA) self.handlegAMA(offset + 8),
                //sBIT
                0b01110011_01000010_01001001_01010100 => if (self.config.sBIT) self.handlesBIT(offset + 8),
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

        pub fn readImageData(self: *Self) !void {
            var offset: u32 = self.idat_start;
            while (offset < self.file_size - 11) {
                offset += try self.readImageDataChunk(offset);
            }
        }

        fn readImageDataChunk(self: *Self, offset: u32) !u32 {
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

            if (self.config.checksum) {
                // initialize CRC
                var crc = zlib.crc32(0, zlib.Z_NULL, 0);

                try self.handleCRC(&crc, offset + 4, data_length);
            }

            switch (data_type) {
                // IDAT
                0b01001001_01000100_01000001_01010100 => try self.handleIDAT(offset + 8, data_length),
                // IEND
                0b01001001_01000101_01001110_01000100 => try self.unFilterIDAT(),
                else => std.debug.print("unhandled chunk {c}{c}{c}{c}\n", .{
                    self.original_img_buffer[offset + 4],
                    self.original_img_buffer[offset + 5],
                    self.original_img_buffer[offset + 6],
                    self.original_img_buffer[offset + 7],
                }),
            }
            return data_length + 12;
        }

        pub fn handleIHDR(self: *Self) !void {
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

            var sample_size: u8 = switch (color_type) {
                // match values represent color type
                // 1: greyscale luminance
                0 => 1,
                // 3: R,G,B
                2 => 3,
                // 1: pallete index
                3 => 1,
                // 2: greyscale luminance + alpha
                4 => 2,
                // 4: R,G,B,A
                6 => 4,

                else => unreachable,
            };

            self.IHDR = .{
                .height = height,
                .width = width,
                .bit_depth = bit_depth,
                .color_type = color_type,
                .compression_method = compression_method,
                .filter_method = filter_method,
                .interlace_method = interlace_method,
            };
            self.sample_size = sample_size;
        }

        /// In PNG spec, crc is derived from the bytes present in the chunk type and chunk data
        fn handleCRC(self: *Self, crc: *c_ulong, type_offset: u32, data_length: u32) PNGReadError!void {
            var end_pos = type_offset + data_length + 4;
            const buffer = self.original_img_buffer[type_offset..end_pos];
            crc.* = zlib.crc32(crc.*, buffer.ptr, data_length + 4);
            const original_crc: u32 =
                @as(u32, self.original_img_buffer[end_pos]) << 24 |
                @as(u32, self.original_img_buffer[end_pos + 1]) << 16 |
                @as(u32, self.original_img_buffer[end_pos + 2]) << 8 |
                @as(u32, self.original_img_buffer[end_pos + 3]);
            if (crc.* != original_crc) {
                return PNGReadError.CorruptedCRC;
            }
        }

        /// appends each IDAT chunk data block to the list of IDAT data in cases of > 1 IDAT chunks
        fn handleIDAT(self: *Self, data_offset: u32, data_length: u32) !void {
            var end_pos = data_offset + data_length;
            const compressed_buf = self.original_img_buffer[data_offset..end_pos];
            _ = try self.idat_list.appendSlice(compressed_buf);
        }

        fn unFilterIDAT(self: *Self) !void {
            var bits_per_line = self.IHDR.width * self.sample_size * self.IHDR.bit_depth;
            // length of BYTES needed to store all pixel data w/o filter byte
            var pixel_len = switch (self.IHDR.bit_depth) {
                8 => self.sample_size * (self.IHDR.height * self.IHDR.width),
                16 => self.sample_size * 2 * (self.IHDR.height * self.IHDR.width),
                else => if (bits_per_line % 8 == 0) bits_per_line / 8 * self.IHDR.height else (bits_per_line / 8 + 1) * self.IHDR.height,
            };

            var uncompressed_len = pixel_len + self.IHDR.height;

            var uncompressed_buf = try self.uncompressed_allocator.alloc(u8, uncompressed_len);
            defer self.uncompressed_allocator.free(uncompressed_buf);

            var pixel_list = try std.ArrayList(u8).initCapacity(self.uncompressed_allocator, pixel_len);

            var dest_len: c_ulong = uncompressed_buf.len;
            _ = zlib.uncompress(uncompressed_buf.ptr, &dest_len, self.idat_list.items.ptr, self.idat_list.items.len);

            var line_width = if (bits_per_line % 8 == 0) bits_per_line / 8 + 1 else (bits_per_line / 8 + 1) + 1;

            for (0..self.IHDR.height) |i| {
                switch (uncompressed_buf[i * line_width]) {
                    1 => unfliter.unFilterSub(uncompressed_buf, i, line_width, self.sample_size),
                    2 => unfliter.unFilterUp(uncompressed_buf, i, line_width, self.sample_size),
                    3 => unfliter.unFilterAverage(uncompressed_buf, i, line_width, self.sample_size),
                    4 => unfliter.unFilterPaeth(uncompressed_buf, i, line_width, self.sample_size),
                    else => {},
                }
                var start_pos = i * line_width + 1;
                var end_pos = start_pos + line_width - 1;
                try pixel_list.appendSlice(uncompressed_buf[start_pos..end_pos]);
            }
            self.pixel_buf = pixel_list.items;
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
                .unit_specifier = self.original_img_buffer[offset + 8],
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

        fn handlesBIT(self: *Self, offset: u32) void {
            self.sBIT = .{
                .sig_grey_bits_t0 = self.original_img_buffer[offset],
                .sig_red_bits_t23 = self.original_img_buffer[offset + 1],
                .sig_green_bits_t23 = self.original_img_buffer[offset + 2],
                .sig_blue_bits_t23 = self.original_img_buffer[offset + 3],
                .sig_grey_bits_t4 = self.original_img_buffer[offset + 4],
                .sig_alpha_bits_t4 = self.original_img_buffer[offset + 5],
                .sig_red_bits_t6 = self.original_img_buffer[offset + 6],
                .sig_green_bits_t6 = self.original_img_buffer[offset + 7],
                .sig_blue_bits_t6 = self.original_img_buffer[offset + 8],
                .sig_alpha_bits_t6 = self.original_img_buffer[offset + 9],
            };
        }

        fn handlePLTE(self: *Self, offset: u32, data_length: u32) !void {
            var entries_num: u32 = undefined;
            if (data_length % 3 != 0) return PNGReadError.PLTENotDivisibleByThree;

            entries_num = data_length / 3;

            //std.debug.print("palette_allocator: {}\n", .{self.palette_allocator});
            var plte_slice = try self.uncompressed_allocator.alloc(u8, data_length);

            for (0..entries_num) |i| {
                var start_pos = i * 3;
                plte_slice[start_pos] = self.original_img_buffer[offset + start_pos];
                plte_slice[start_pos + 1] = self.original_img_buffer[offset + start_pos + 1];
                plte_slice[start_pos + 2] = self.original_img_buffer[offset + start_pos + 2];
            }

            self.PLTE = .{
                .sections = plte_slice,
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
            _ = gama;
        }

        pub fn print(self: *Self) void {
            //std.debug.print("width {any}\n", .{self.IHDR.width});
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
            for (0..self.pixel_buf.len) |i| {
                std.debug.print("val at {d}: {any}\n", .{ i, self.pixel_buf[i] });
            }
            // std.debug.print("idat_list.len after: {any}\n\n", .{self.idat_list.items.len});

        }
    };
}
