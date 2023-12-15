const std = @import("std");
const chunks = @import("./chunks.zig");
const unfliter = @import("./unfilter.zig");
const zlib = @cImport(@cInclude("zlib.h"));

const ChunkTypes = chunks.ChunkTypes;
const assert = std.debug.assert;

const PNG_SIGNATURE = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

const PNGReadError = error{
    NotPNG,
    CorruptedCRC,
    PLTENotDivisibleByThree,
    hISTNotValidU16Slice,
    InvalidCompressionMethod,
    ZlibInflateInitError,
    ZlibMemoryError,
};

/// defines whether or not to process the following
const DecoderConfig = struct {
    checksum: bool = true,
    pHYS: bool = false,
    bKGD: bool = false,
    sRGB: bool = false,
    sBIT: bool = false,
    gAMA: bool = false,
    cHRM: bool = false,
    hIST: bool = false,
    tIME: bool = false,
    tEXt: bool = false,
    zTXt: bool = false,
    iTXt: bool = false,
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

        tEXt_list: ?std.ArrayList(chunks.tEXt),
        zTXt_list: ?std.ArrayList(chunks.zTXt),
        iTXt_list: ?std.ArrayList(chunks.iTXt),

        IHDR: chunks.IHDR,
        pHYS: ?chunks.pHYs = null,
        bKGD: ?chunks.bKGD = null,
        sRGB: ?chunks.sRGB = null,
        sBIT: ?chunks.sBIT = null,
        gAMA: ?chunks.gAMA = null,
        PLTE: ?chunks.PLTE = null,
        tRNS: ?chunks.tRNS = null,
        cHRM: ?chunks.cHRM = null,
        hIST: ?chunks.hIST = null,
        tIME: ?chunks.tIME = null,

        config: DecoderConfig,

        /// idat_allocator used by ArrayList to store a consecutive u8 slice made from all appended, uncompressed, IDAT chunk data
        ///
        /// uncompressed_allocator used by zlib to store just the decompressed IDAT chunk data with filter byte intact at scanline start
        pub fn init(idatAllocator: std.mem.Allocator, uncompressedAllocator: std.mem.Allocator, config: DecoderConfig) !Self {
            var idat_list = std.ArrayList(u8).init(
                idatAllocator,
            );
            var tEXt_list: ?std.ArrayList(chunks.tEXt) = null;
            if (config.tEXt == true) {
                tEXt_list = std.ArrayList(chunks.tEXt).init(
                    uncompressedAllocator,
                );
            }
            var zTXt_list: ?std.ArrayList(chunks.zTXt) = null;
            if (config.zTXt == true) {
                zTXt_list = std.ArrayList(chunks.zTXt).init(
                    uncompressedAllocator,
                );
            }
            var iTXt_list: ?std.ArrayList(chunks.iTXt) = null;
            if (config.iTXt == true) {
                iTXt_list = std.ArrayList(chunks.iTXt).init(
                    uncompressedAllocator,
                );
            }

            return Self{
                .idat_list = idat_list,
                .tEXt_list = tEXt_list,
                .zTXt_list = zTXt_list,
                .iTXt_list = iTXt_list,
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
            if (self.hIST != null) self.uncompressed_allocator.free(self.hIST.?.frequencies);

            if (self.tEXt_list != null) {
                self.tEXt_list.?.clearAndFree();
                self.tEXt_list = null;
            }
            if (self.zTXt_list != null) {
                for (self.zTXt_list.?.items) |zTXt| {
                    self.uncompressed_allocator.free(zTXt.uncompressed_text);
                }
                self.zTXt_list.?.clearAndFree();
                self.zTXt_list = null;
            }
            if (self.iTXt_list != null) {
                for (self.iTXt_list.?.items) |iTXt| {
                    if (iTXt.compression_flag == 1) {
                        self.uncompressed_allocator.free(iTXt.uncompressed_text);
                    }
                }
                self.iTXt_list.?.clearAndFree();
                self.iTXt_list = null;
            }
            if (self.tRNS != null) {
                if (self.tRNS.?.alphas != null) self.uncompressed_allocator.free(self.tRNS.?.alphas.?);
            }
            self.* = undefined;
        }

        /// Resets the decoder to its original state and frees memory while sill holding references to both allocators
        pub fn reset(self: *Self) void {
            self.original_img_allocator.free(self.original_img_buffer);
            self.original_img_buffer = undefined;
            self.idat_list.clearAndFree();
            self.uncompressed_allocator.free(self.pixel_buf);
            if (self.hIST != null) self.uncompressed_allocator.free(self.hIST.?.frequencies);
            if (self.tEXt_list != null) {
                self.tEXt_list.?.clearAndFree();
                self.tEXt_list = null;
            }
            if (self.zTXt_list != null) {
                for (self.zTXt_list.?.items) |zTXt| {
                    self.uncompressed_allocator.free(zTXt.uncompressed_text);
                }
                self.zTXt_list.?.clearAndFree();
                self.zTXt_list = null;
            }
            if (self.iTXt_list != null) {
                for (self.iTXt_list.?.items) |iTXt| {
                    if (iTXt.compression_flag == 1) {
                        self.uncompressed_allocator.free(iTXt.uncompressed_text);
                    }
                }
                self.iTXt_list.?.clearAndFree();
                self.iTXt_list = null;
            }
            if (self.tRNS != null) {
                if (self.tRNS.?.alphas != null) self.uncompressed_allocator.free(self.tRNS.?.alphas.?);
            }

            self.file_size = undefined;
            self.pixel_buf = undefined;
            self.sample_size = undefined;

            self.IHDR = undefined;

            self.pHYS = null;
            self.bKGD = null;
            self.sRGB = null;
            self.tRNS = null;
            self.gAMA = null;
            self.cHRM = null;
            self.hIST = null;
            self.tIME = null;
            self.zTXt = null;
            self.iTXt = null;
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
                @intFromEnum(ChunkTypes.IDAT) => {
                    return 0;
                },
                @intFromEnum(ChunkTypes.IHDR) => try self.handleIHDR(),
                @intFromEnum(ChunkTypes.PLTE) => try self.handlePLTE(offset + 8, data_length),
                @intFromEnum(ChunkTypes.tRNS) => try self.handletRNS(offset + 8, data_length),
                @intFromEnum(ChunkTypes.hIST) => if (self.config.hIST) try self.handlehIST(offset + 8, data_length),
                @intFromEnum(ChunkTypes.tEXt) => if (self.config.tEXt) try self.handletEXt(offset + 8, data_length),
                @intFromEnum(ChunkTypes.zTXt) => if (self.config.zTXt) try self.handlezTXt(offset + 8, data_length),
                @intFromEnum(ChunkTypes.iTXt) => if (self.config.iTXt) try self.handleiTXt(offset + 8, data_length),
                @intFromEnum(ChunkTypes.pHYs) => if (self.config.pHYS) self.handlepHYs(offset + 8),
                @intFromEnum(ChunkTypes.bKGD) => if (self.config.bKGD) self.handlebKGD(offset + 8),
                @intFromEnum(ChunkTypes.sRGB) => if (self.config.sRGB) self.handlesRGB(offset + 8),
                @intFromEnum(ChunkTypes.gAMA) => if (self.config.gAMA) self.handlegAMA(offset + 8),
                @intFromEnum(ChunkTypes.cHRM) => if (self.config.cHRM) self.handlecHRM(offset + 8),
                @intFromEnum(ChunkTypes.tIME) => if (self.config.tIME) self.handletIME(offset + 8),
                @intFromEnum(ChunkTypes.sBIT) => if (self.config.sBIT) self.handlesBIT(offset + 8),
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
                @intFromEnum(ChunkTypes.IDAT) => try self.handleIDAT(offset + 8, data_length),
                @intFromEnum(ChunkTypes.IEND) => try self.unFilterIDAT(),
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

        fn handlecHRM(self: *Self, offset: u32) void {
            const white_point_x: u32 =
                @as(u32, self.original_img_buffer[offset]) << 24 |
                @as(u32, self.original_img_buffer[offset + 1]) << 16 |
                @as(u32, self.original_img_buffer[offset + 2]) << 8 |
                @as(u32, self.original_img_buffer[offset + 3]);
            const white_point_y: u32 =
                @as(u32, self.original_img_buffer[offset + 4]) << 24 |
                @as(u32, self.original_img_buffer[offset + 5]) << 16 |
                @as(u32, self.original_img_buffer[offset + 6]) << 8 |
                @as(u32, self.original_img_buffer[offset + 7]);
            const red_x: u32 =
                @as(u32, self.original_img_buffer[offset + 8]) << 24 |
                @as(u32, self.original_img_buffer[offset + 9]) << 16 |
                @as(u32, self.original_img_buffer[offset + 10]) << 8 |
                @as(u32, self.original_img_buffer[offset + 11]);
            const red_y: u32 =
                @as(u32, self.original_img_buffer[offset + 12]) << 24 |
                @as(u32, self.original_img_buffer[offset + 13]) << 16 |
                @as(u32, self.original_img_buffer[offset + 14]) << 8 |
                @as(u32, self.original_img_buffer[offset + 15]);
            const green_x: u32 =
                @as(u32, self.original_img_buffer[offset + 16]) << 24 |
                @as(u32, self.original_img_buffer[offset + 17]) << 16 |
                @as(u32, self.original_img_buffer[offset + 18]) << 8 |
                @as(u32, self.original_img_buffer[offset + 19]);
            const green_y: u32 =
                @as(u32, self.original_img_buffer[offset + 20]) << 24 |
                @as(u32, self.original_img_buffer[offset + 21]) << 16 |
                @as(u32, self.original_img_buffer[offset + 22]) << 8 |
                @as(u32, self.original_img_buffer[offset + 23]);
            const blue_x: u32 =
                @as(u32, self.original_img_buffer[offset + 24]) << 24 |
                @as(u32, self.original_img_buffer[offset + 25]) << 16 |
                @as(u32, self.original_img_buffer[offset + 26]) << 8 |
                @as(u32, self.original_img_buffer[offset + 27]);
            const blue_y: u32 =
                @as(u32, self.original_img_buffer[offset + 28]) << 24 |
                @as(u32, self.original_img_buffer[offset + 29]) << 16 |
                @as(u32, self.original_img_buffer[offset + 30]) << 8 |
                @as(u32, self.original_img_buffer[offset + 31]);

            self.cHRM = .{
                .white_point_x = white_point_x,
                .white_point_y = white_point_y,
                .red_x = red_x,
                .red_y = red_y,
                .green_x = green_x,
                .green_y = green_y,
                .blue_x = blue_x,
                .blue_y = blue_y,
            };
        }

        fn handlebKGD(self: *Self, offset: u32) void {
            var greyscale: ?u16 = null;
            var red: ?u16 = null;
            var green: ?u16 = null;
            var blue: ?u16 = null;
            var palette_index: ?u8 = null;

            switch (self.IHDR.color_type) {
                0, 4 => {
                    greyscale =
                        @as(u16, self.original_img_buffer[offset]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 1]);
                },
                2, 6 => {
                    red =
                        @as(u16, self.original_img_buffer[offset]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 1]);
                    green =
                        @as(u16, self.original_img_buffer[offset + 2]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 3]);

                    blue =
                        @as(u16, self.original_img_buffer[offset + 4]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 5]);
                },

                3 => {
                    palette_index = self.original_img_buffer[offset];
                },
                else => unreachable,
            }

            self.bKGD = .{
                .greyscale = greyscale,
                .red = red,
                .green = green,
                .blue = blue,
                .palette_index = palette_index,
            };
        }

        fn handletRNS(self: *Self, offset: u32, data_length: u32) !void {
            var grey_sample: ?u16 = null;
            var red_sample: ?u16 = null;
            var green_sample: ?u16 = null;
            var blue_sample: ?u16 = null;
            var alphas: ?[]u8 = null;

            switch (self.IHDR.color_type) {
                0 => {
                    grey_sample =
                        @as(u16, self.original_img_buffer[offset]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 1]);
                },
                2 => {
                    red_sample =
                        @as(u16, self.original_img_buffer[offset]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 1]);
                    green_sample =
                        @as(u16, self.original_img_buffer[offset + 2]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 3]);
                    blue_sample =
                        @as(u16, self.original_img_buffer[offset + 4]) << 8 |
                        @as(u16, self.original_img_buffer[offset + 5]);
                },

                3 => {
                    alphas = try self.uncompressed_allocator.alloc(u8, data_length);
                    for (0..data_length) |i| {
                        alphas.?[i] = self.original_img_buffer[offset + i];
                    }
                },
                else => unreachable,
            }
            self.tRNS = .{
                .grey_sample = grey_sample,
                .red_sample = red_sample,
                .green_sample = green_sample,
                .blue_sample = blue_sample,
                .alphas = alphas,
            };
        }

        fn handlesBIT(self: *Self, offset: u32) void {
            var sig_grey_bits_t0: ?u8 = null;
            var sig_red_bits_t23: ?u8 = null;
            var sig_green_bits_t23: ?u8 = null;
            var sig_blue_bits_t23: ?u8 = null;
            var sig_grey_bits_t4: ?u8 = null;
            var sig_alpha_bits_t4: ?u8 = null;
            var sig_red_bits_t6: ?u8 = null;
            var sig_green_bits_t6: ?u8 = null;
            var sig_blue_bits_t6: ?u8 = null;
            var sig_alpha_bits_t6: ?u8 = null;

            switch (self.IHDR.color_type) {
                0 => sig_grey_bits_t0 = self.original_img_buffer[offset],
                2, 3 => {
                    sig_red_bits_t23 = self.original_img_buffer[offset];
                    sig_green_bits_t23 = self.original_img_buffer[offset + 1];
                    sig_blue_bits_t23 = self.original_img_buffer[offset + 2];
                },
                4 => {
                    sig_grey_bits_t4 = self.original_img_buffer[offset];
                    sig_alpha_bits_t4 = self.original_img_buffer[offset + 1];
                },
                6 => {
                    sig_red_bits_t6 = self.original_img_buffer[offset];
                    sig_green_bits_t6 = self.original_img_buffer[offset + 1];
                    sig_blue_bits_t6 = self.original_img_buffer[offset + 2];
                    sig_alpha_bits_t6 = self.original_img_buffer[offset + 3];
                },
                else => unreachable,
            }

            self.sBIT = .{
                .sig_grey_bits_t0 = sig_grey_bits_t0,
                .sig_red_bits_t23 = sig_red_bits_t23,
                .sig_green_bits_t23 = sig_green_bits_t23,
                .sig_blue_bits_t23 = sig_blue_bits_t23,
                .sig_grey_bits_t4 = sig_grey_bits_t4,
                .sig_alpha_bits_t4 = sig_alpha_bits_t4,
                .sig_red_bits_t6 = sig_red_bits_t6,
                .sig_green_bits_t6 = sig_green_bits_t6,
                .sig_blue_bits_t6 = sig_blue_bits_t6,
                .sig_alpha_bits_t6 = sig_alpha_bits_t6,
            };
        }

        fn handlePLTE(self: *Self, offset: u32, data_length: u32) !void {
            if (data_length % 3 != 0) return PNGReadError.PLTENotDivisibleByThree;
            const end_pos = data_length + offset;

            self.PLTE = .{
                .sections = self.original_img_buffer[offset..end_pos],
            };
        }

        fn handlehIST(self: *Self, offset: u32, data_length: u32) !void {
            var hist_len: u32 = undefined;

            if (data_length % 2 == 0) {
                hist_len = data_length / 2;
            } else {
                return PNGReadError.hISTNotValidU16Slice;
            }
            var frequencies_slice = try self.uncompressed_allocator.alloc(u16, hist_len);

            for (0..hist_len) |i| {
                var frequency: u16 =
                    @as(u16, self.original_img_buffer[offset + i]) << 8 |
                    @as(u16, self.original_img_buffer[offset + i + 1]);
                frequencies_slice[i] = frequency;
            }

            self.hIST = .{
                .frequencies = frequencies_slice,
            };
        }

        fn handletIME(self: *Self, offset: u32) void {
            const year: u16 = @as(u16, self.original_img_buffer[offset]) << 8 |
                @as(u16, self.original_img_buffer[offset + 1]);

            self.tIME = .{
                .year = year,
                .month = self.original_img_buffer[offset + 2],
                .day = self.original_img_buffer[offset + 3],
                .hour = self.original_img_buffer[offset + 4],
                .minute = self.original_img_buffer[offset + 5],
                .second = self.original_img_buffer[offset + 6],
            };
        }

        fn handletEXt(self: *Self, offset: u32, data_length: u32) !void {
            var keyword: []u8 = undefined;
            var text: []u8 = undefined;

            const end_pos = offset + data_length;
            const null_pos = std.mem.indexOfScalar(u8, self.original_img_buffer[offset..end_pos], 0).?;
            const keyword_end = offset + null_pos;
            keyword = self.original_img_buffer[offset..keyword_end];
            const text_start = offset + null_pos + 1;
            const text_end = offset + data_length;
            text = self.original_img_buffer[text_start..text_end];

            try self.tEXt_list.?.append(.{
                .keyword = keyword,
                .text = text,
            });
        }

        fn handlezTXt(self: *Self, offset: u32, data_length: u32) !void {
            var keyword: []u8 = undefined;
            var compression_method: u8 = undefined;

            // check out https://www.zlib.net/zlib_how.html
            const chunk: c_uint = 1024;
            var temp_out_list = std.ArrayList(u8).init(self.uncompressed_allocator);
            var temp_out_buf: [chunk]u8 = undefined;
            var zlib_ret: c_int = undefined;
            var decompressed_count: c_uint = undefined;

            const end_pos = offset + data_length;
            // safe downcast. chunk size always < 2^31
            const null_pos = @as(u32, @intCast(std.mem.indexOfScalar(u8, self.original_img_buffer[offset..end_pos], 0).?));
            const keyword_end = null_pos + offset;

            keyword = self.original_img_buffer[offset..keyword_end];
            compression_method = self.original_img_buffer[keyword_end + 1];
            if (compression_method != 0) return PNGReadError.InvalidCompressionMethod;

            var text_start = offset + null_pos + 2;
            var text_end = offset + data_length;

            var strm: zlib.z_stream = .{
                .avail_in = 0,
                .next_in = null,
                .zalloc = null,
                .zfree = null,
                .@"opaque" = null,
            };
            zlib_ret = zlib.inflateInit(&strm);

            if (zlib_ret != zlib.Z_OK) return PNGReadError.ZlibInflateInitError;

            strm.avail_in = @as(c_uint, @intCast(text_end)) - text_start;
            strm.next_in = self.original_img_buffer[text_start..text_end].ptr;
            while (strm.avail_out == 0 or zlib_ret != zlib.Z_STREAM_END) {
                // set out buffer
                strm.next_out = &temp_out_buf;
                strm.avail_out = chunk;

                zlib_ret = zlib.inflate(&strm, zlib.Z_NO_FLUSH);
                switch (zlib_ret) {
                    zlib.Z_NEED_DICT => zlib_ret = zlib.Z_DATA_ERROR,
                    zlib.Z_MEM_ERROR => {
                        _ = zlib.inflateEnd(&strm);
                        return PNGReadError.ZlibMemoryError;
                    },
                    else => {},
                }
                decompressed_count = chunk - strm.avail_out;
                try temp_out_list.appendSlice(temp_out_buf[0..decompressed_count]);
            }
            // trim out extra memory from temporary list to give us a clean chunk
            // of decompressed text data
            temp_out_list.shrinkAndFree(temp_out_list.items.len);
            _ = zlib.inflateEnd(&strm);
            try self.zTXt_list.?.append(.{
                .keyword = keyword,
                .compression_method = compression_method,
                .uncompressed_text = temp_out_list.items,
            });
        }

        fn handleiTXt(self: *Self, offset: u32, data_length: u32) !void {
            var keyword: []u8 = undefined;
            var compression_flag: u8 = undefined;
            var compression_method: u8 = undefined;
            var language_tag: []u8 = undefined;
            var translated_keyword: []u8 = undefined;
            var uncompressed_text: []u8 = undefined;

            const end_pos = offset + data_length;
            const null_one = @as(u32, @intCast(std.mem.indexOfScalar(u8, self.original_img_buffer[offset..end_pos], 0).?));
            const keyword_end = offset + null_one;
            keyword = self.original_img_buffer[offset..keyword_end];
            compression_flag = self.original_img_buffer[offset + null_one + 1];
            compression_method = self.original_img_buffer[offset + null_one + 2];

            const language_tag_start_abs = offset + null_one + 3;
            if (compression_method != 0) return PNGReadError.InvalidCompressionMethod;
            const null_two = @as(u32, @intCast(std.mem.indexOfScalar(u8, self.original_img_buffer[language_tag_start_abs..end_pos], 0).?));
            const language_tag_end_abs = language_tag_start_abs + null_two;
            language_tag = self.original_img_buffer[language_tag_start_abs..language_tag_end_abs];

            const translated_keyword_start_abs = language_tag_end_abs + 1;
            const null_three = @as(u32, @intCast(std.mem.indexOfScalar(u8, self.original_img_buffer[translated_keyword_start_abs..end_pos], 0).?));
            const translated_keyword_end_abs = translated_keyword_start_abs + null_three;

            translated_keyword = self.original_img_buffer[translated_keyword_start_abs..translated_keyword_end_abs];

            const uncompressed_text_start_abs = translated_keyword_end_abs + 1;
            if (compression_flag == 0) {
                uncompressed_text = self.original_img_buffer[uncompressed_text_start_abs..end_pos];
                try self.iTXt_list.?.append(.{
                    .keyword = keyword,
                    .compression_flag = compression_flag,
                    .compression_method = compression_method,
                    .language_tag = language_tag,
                    .translated_keyword = translated_keyword,
                    .uncompressed_text = uncompressed_text,
                });
                return;
            }

            const chunk: c_uint = 1024;
            var temp_out_list = std.ArrayList(u8).init(self.uncompressed_allocator);
            var temp_out_buf: [chunk]u8 = undefined;
            var decompressed_count: c_uint = undefined;
            var zlib_ret: c_int = undefined;

            var strm: zlib.z_stream = .{
                .avail_in = 0,
                .next_in = null,
                .zalloc = null,
                .zfree = null,
                .@"opaque" = null,
            };
            zlib_ret = zlib.inflateInit(&strm);

            if (zlib_ret != zlib.Z_OK) return PNGReadError.ZlibInflateInitError;

            strm.avail_in = @as(c_uint, @intCast(end_pos)) - uncompressed_text_start_abs;
            strm.next_in = self.original_img_buffer[uncompressed_text_start_abs..end_pos].ptr;
            while (strm.avail_out == 0 or zlib_ret != zlib.Z_STREAM_END) {
                // set out buffer
                strm.next_out = &temp_out_buf;
                strm.avail_out = chunk;

                zlib_ret = zlib.inflate(&strm, zlib.Z_NO_FLUSH);
                switch (zlib_ret) {
                    zlib.Z_NEED_DICT => zlib_ret = zlib.Z_DATA_ERROR,
                    zlib.Z_MEM_ERROR => {
                        _ = zlib.inflateEnd(&strm);
                        return PNGReadError.ZlibMemoryError;
                    },
                    else => {},
                }
                decompressed_count = chunk - strm.avail_out;
                try temp_out_list.appendSlice(temp_out_buf[0..decompressed_count]);
            }
            // trim out extra memory from temporary list to give us a clean chunk
            // of decompressed text data
            temp_out_list.shrinkAndFree(temp_out_list.items.len);
            _ = zlib.inflateEnd(&strm);

            try self.iTXt_list.?.append(.{
                .keyword = keyword,
                .compression_flag = compression_flag,
                .compression_method = compression_method,
                .language_tag = language_tag,
                .translated_keyword = translated_keyword,
                .uncompressed_text = temp_out_list.items,
            });
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

            self.gAMA = .{
                .image_gama = gama,
            };
        }
    };
}
