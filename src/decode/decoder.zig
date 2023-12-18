const std = @import("std");
const chunks = @import("./chunks.zig");
const handlers = @import("handlers.zig");
const zlib = @cImport(@cInclude("zlib.h"));
const ChunkTypes = chunks.ChunkTypes;
const errors = @import("errors.zig");
const assert = std.debug.assert;

const PNGReadError = errors.PNGReadError;
const PNG_SIGNATURE = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

/// defines whether or not to process the following
const DecoderConfig = struct {
    checksum: bool = true,
    pHYS: bool = false,
    bKGD: bool = false,
    sRGB: bool = false,
    sBIT: bool = false,
    sPLT: bool = false,
    gAMA: bool = false,
    cHRM: bool = false,
    hIST: bool = false,
    tIME: bool = false,
    tEXt: bool = false,
    zTXt: bool = false,
    iTXt: bool = false,
    eXIf: bool = false,
    iCCP: bool = false,
    cICP: bool = false,
    mDCv: bool = false,
    cLLi: bool = false,
    animation: bool = false,
};

pub fn pngDecoder() type {
    return struct {
        const Self = @This();
        original_img_buffer: []u8 = undefined,
        original_img_allocator: std.mem.Allocator = undefined,
        file_size: u64 = 0,

        image_data_start: u32 = 0,
        curr_sequence_num: u32 = 0,
        image_data_list: std.ArrayList(u8) = undefined,
        idat_allocator: std.mem.Allocator = undefined,

        pixel_buf: []u8 = undefined,
        uncompressed_allocator: std.mem.Allocator = undefined,

        sample_size: u8 = undefined,

        tEXt_list: ?std.ArrayList(chunks.tEXt),
        zTXt_list: ?std.ArrayList(chunks.zTXt),
        iTXt_list: ?std.ArrayList(chunks.iTXt),
        sPLT_list: ?std.ArrayList(chunks.sPLT),
        fcTL_list: ?std.ArrayList(chunks.fcTL),
        fdAT_list: ?std.ArrayList(chunks.fdAT),

        IHDR: chunks.IHDR = undefined,
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
        iCCP: ?chunks.iCCP = null,
        eXIf: ?chunks.eXIf = null,
        cICP: ?chunks.cICP = null,
        mDCv: ?chunks.mDCv = null,
        cLLi: ?chunks.cLLi = null,
        acTL: ?chunks.acTL = null,

        config: DecoderConfig,

        /// idat_allocator used by ArrayList to store a consecutive u8 slice made from all appended, uncompressed, IDAT chunk data
        ///
        /// uncompressed_allocator used by zlib to store just the decompressed IDAT chunk data with filter byte intact at scanline start
        pub fn init(idatAllocator: std.mem.Allocator, uncompressedAllocator: std.mem.Allocator, config: DecoderConfig) !Self {
            var image_data_list = std.ArrayList(u8).init(
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
            var sPLT_list: ?std.ArrayList(chunks.sPLT) = null;
            if (config.sPLT == true) {
                sPLT_list = std.ArrayList(chunks.sPLT).init(
                    uncompressedAllocator,
                );
            }

            var fcTL_list: ?std.ArrayList(chunks.fcTL) = null;
            if (config.animation) {
                fcTL_list = std.ArrayList(chunks.fcTL).init(
                    uncompressedAllocator,
                );
            }

            var fdAT_list: ?std.ArrayList(chunks.fdAT) = null;
            if (config.animation) {
                fdAT_list = std.ArrayList(chunks.fdAT).init(
                    uncompressedAllocator,
                );
            }

            return Self{
                .image_data_list = image_data_list,
                .tEXt_list = tEXt_list,
                .zTXt_list = zTXt_list,
                .iTXt_list = iTXt_list,
                .sPLT_list = sPLT_list,
                .fcTL_list = fcTL_list,
                .fdAT_list = fdAT_list,
                .idat_allocator = idatAllocator,
                .uncompressed_allocator = uncompressedAllocator,
                .config = config,
            };
        }

        /// Cannot reuse this decoder instance after this operation
        pub fn deinit(self: *Self) void {
            self.image_data_list.deinit();
            self.original_img_allocator.free(self.original_img_buffer);
            self.uncompressed_allocator.free(self.pixel_buf);
            if (self.hIST != null) self.uncompressed_allocator.free(self.hIST.?.frequencies);

            if (self.tEXt_list != null) {
                self.tEXt_list.?.clearAndFree();
            }
            if (self.zTXt_list != null) {
                for (self.zTXt_list.?.items) |zTXt| {
                    self.uncompressed_allocator.free(zTXt.text);
                }
                self.zTXt_list.?.clearAndFree();
            }
            if (self.iTXt_list != null) {
                for (self.iTXt_list.?.items) |iTXt| {
                    if (iTXt.compression_flag == 1) {
                        self.uncompressed_allocator.free(iTXt.text);
                    }
                }
                self.iTXt_list.?.clearAndFree();
            }
            if (self.tRNS != null) {
                if (self.tRNS.?.alphas != null) self.uncompressed_allocator.free(self.tRNS.?.alphas.?);
            }
            if (self.sPLT_list != null) {
                for (self.sPLT_list.?.items) |sPLT| {
                    self.uncompressed_allocator.free(sPLT.palette);
                }
                self.sPLT_list.?.clearAndFree();
            }
            if (self.iCCP != null) {
                self.uncompressed_allocator.free(self.iCCP.?.profile);
            }

            if (self.fcTL_list != null) {
                self.fcTL_list.?.clearAndFree();
            }
            self.* = undefined;
        }

        /// Resets the decoder to its original state and frees memory while sill holding references to both allocators
        pub fn reset(self: *Self) void {
            self.original_img_allocator.free(self.original_img_buffer);
            self.original_img_buffer = undefined;
            self.image_data_list.clearAndFree();
            self.uncompressed_allocator.free(self.pixel_buf);
            if (self.hIST != null) self.uncompressed_allocator.free(self.hIST.?.frequencies);
            if (self.sPLT != null) self.uncompressed_allocator.free(self.sPLT);
            if (self.tEXt_list != null) {
                self.tEXt_list.?.clearAndFree();
                self.tEXt_list = null;
            }
            if (self.zTXt_list != null) {
                for (self.zTXt_list.?.items) |zTXt| {
                    self.uncompressed_allocator.free(zTXt.text);
                }
                self.zTXt_list.?.clearAndFree();
                self.zTXt_list = null;
            }
            if (self.iTXt_list != null) {
                for (self.iTXt_list.?.items) |iTXt| {
                    if (iTXt.compression_flag == 1) {
                        self.uncompressed_allocator.free(iTXt.text);
                    }
                }
                self.iTXt_list.?.clearAndFree();
                self.iTXt_list = null;
            }
            if (self.sPLT_list != null) {
                for (self.sPLT_list.?.items) |sPLT| {
                    self.uncompressed_allocator.free(sPLT.palette);
                }
                self.sPLT_list.?.clearAndFree();
                self.sPLT_list = null;
            }
            if (self.tRNS != null) {
                if (self.tRNS.?.alphas != null) {
                    self.uncompressed_allocator.free(self.tRNS.?.alphas.?);
                    self.tRNS = null;
                }
            }

            if (self.iCCP != null) {
                self.uncompressed_allocator.free(self.iCCP.?.profile);
                self.iCCP = null;
            }
            if (self.fcTL_list != null) {
                self.fcTL_list.?.clearAndFree();
            }
            self.file_size = undefined;
            self.pixel_buf = undefined;
            self.sample_size = undefined;
            self.image_data_start = 0;

            self.IHDR = undefined;

            self.pHYS = null;
            self.bKGD = null;
            self.sRGB = null;
            self.gAMA = null;
            self.cHRM = null;
            self.hIST = null;
            self.tIME = null;
            self.zTXt = null;
            self.iTXt = null;
            self.eXIf = null;
            self.cICP = null;
            self.mDCv = null;
            self.cLLi = null;
            self.acTL = null;
            self.fcTL = null;
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
            while (offset < self.file_size - 11) {
                var temp: u32 = try self.readInfoChunk(offset);
                offset += temp;
            }
        }

        /// searches for any info/ancillary chunks before AND after IDAT chunks.
        ///
        /// does not process IDAT chunks.
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

            // defer IDAT checksum until the readImageData function to avoid
            // duplicating work
            if (self.config.checksum and data_type != @intFromEnum(ChunkTypes.IDAT)) {
                // initialize CRC
                var crc = zlib.crc32(0, zlib.Z_NULL, 0);

                try handlers.handleCRC(self, &crc, offset + 4, data_length);
            }

            switch (data_type) {
                // if we come across image data, set the start point to be here
                // if the start point isn't at zero (we already found image data),
                // continue reading info while ignoring image data
                @intFromEnum(ChunkTypes.IDAT) => {
                    if (self.image_data_start == 0) {
                        self.image_data_start = offset;
                    }
                },
                @intFromEnum(ChunkTypes.fcTL) => {
                    if (self.image_data_start == 0) {
                        self.image_data_start = offset;
                    }
                },
                @intFromEnum(ChunkTypes.fdAT) => {},
                @intFromEnum(ChunkTypes.IEND) => {},
                @intFromEnum(ChunkTypes.IHDR) => try handlers.handleIHDR(self),
                @intFromEnum(ChunkTypes.PLTE) => try handlers.handlePLTE(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.tRNS) => try handlers.handletRNS(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.eXIf) => if (self.config.eXIf) handlers.handleeXIf(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.hIST) => if (self.config.hIST) try handlers.handlehIST(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.tEXt) => if (self.config.tEXt) try handlers.handletEXt(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.zTXt) => if (self.config.zTXt) try handlers.handlezTXt(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.iTXt) => if (self.config.iTXt) try handlers.handleiTXt(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.sPLT) => if (self.config.sPLT) try handlers.handlesPLT(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.pHYs) => if (self.config.pHYS) handlers.handlepHYs(self, offset + 8),
                @intFromEnum(ChunkTypes.bKGD) => if (self.config.bKGD) handlers.handlebKGD(self, offset + 8),
                @intFromEnum(ChunkTypes.sRGB) => if (self.config.sRGB) handlers.handlesRGB(self, offset + 8),
                @intFromEnum(ChunkTypes.gAMA) => if (self.config.gAMA) handlers.handlegAMA(self, offset + 8),
                @intFromEnum(ChunkTypes.cHRM) => if (self.config.cHRM) handlers.handlecHRM(self, offset + 8),
                @intFromEnum(ChunkTypes.tIME) => if (self.config.tIME) handlers.handletIME(self, offset + 8),
                @intFromEnum(ChunkTypes.mDCv) => if (self.config.mDCv) handlers.handlemDCv(self, offset + 8),
                @intFromEnum(ChunkTypes.acTL) => if (self.config.animation) handlers.handleacTL(self, offset + 8),
                @intFromEnum(ChunkTypes.cLLi) => if (self.config.cLLi) handlers.handlecLLi(self, offset + 8),
                @intFromEnum(ChunkTypes.cICP) => if (self.config.cICP) try handlers.handlecICP(self, offset + 8),
                @intFromEnum(ChunkTypes.iCCP) => if (self.config.iCCP) try handlers.handleiCCP(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.sBIT) => if (self.config.sBIT) handlers.handlesBIT(self, offset + 8),
                else => {},
            }
            // 4 byte length + 4 byte type + {{data_length}} data + 4 byte crc
            return data_length + 12;
        }

        pub fn readImageData(self: *Self) !void {
            var offset: u32 = self.image_data_start;
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

                try handlers.handleCRC(self, &crc, offset + 4, data_length);
            }

            switch (data_type) {
                @intFromEnum(ChunkTypes.IDAT) => try handlers.handleIDAT(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.fcTL) => if (self.config.animation) try handlers.handlefcTL(self, offset + 8),
                @intFromEnum(ChunkTypes.fdAT) => if (self.config.animation) try handlers.handlefdAT(self, offset + 8, data_length),
                @intFromEnum(ChunkTypes.IEND) => try handlers.unFilterImageData(self),

                else => {},
            }
            return data_length + 12;
        }
    };
}
