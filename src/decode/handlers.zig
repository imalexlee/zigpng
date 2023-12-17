const std = @import("std");
const png_decoder = @import("decoder.zig");
const Decoder = png_decoder.pngDecoder();
const unfliter = @import("./unfilter.zig");
const chunks = @import("./chunks.zig");
const PNGReadError = png_decoder.PNGReadError;
const zlib = @cImport(@cInclude("zlib.h"));

// NON CHUNKS

/// In PNG spec, crc is derived from the bytes present in the chunk type and chunk data
pub fn handleCRC(decoder: *Decoder, crc: *c_ulong, type_offset: u32, data_length: u32) PNGReadError!void {
    var end_pos = type_offset + data_length + 4;
    const buffer = decoder.original_img_buffer[type_offset..end_pos];
    crc.* = zlib.crc32(crc.*, buffer.ptr, data_length + 4);
    const original_crc: u32 =
        @as(u32, decoder.original_img_buffer[end_pos]) << 24 |
        @as(u32, decoder.original_img_buffer[end_pos + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[end_pos + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[end_pos + 3]);
    if (crc.* != original_crc) {
        return PNGReadError.CorruptedCRC;
    }
}
pub fn unFilterIDAT(decoder: *Decoder) !void {
    const bits_per_line = decoder.IHDR.width * decoder.sample_size * decoder.IHDR.bit_depth;
    // length of BYTES needed to store all pixel data w/o filter byte
    const pixel_len = switch (decoder.IHDR.bit_depth) {
        8 => decoder.sample_size * (decoder.IHDR.height * decoder.IHDR.width),
        16 => decoder.sample_size * 2 * (decoder.IHDR.height * decoder.IHDR.width),
        else => if (bits_per_line % 8 == 0) bits_per_line / 8 * decoder.IHDR.height else (bits_per_line / 8 + 1) * decoder.IHDR.height,
    };

    const uncompressed_len = pixel_len + decoder.IHDR.height;

    const uncompressed_buf = try decoder.uncompressed_allocator.alloc(u8, uncompressed_len);
    defer decoder.uncompressed_allocator.free(uncompressed_buf);

    var pixel_list = try std.ArrayList(u8).initCapacity(decoder.uncompressed_allocator, pixel_len);

    var dest_len: c_ulong = uncompressed_buf.len;
    _ = zlib.uncompress(uncompressed_buf.ptr, &dest_len, decoder.idat_list.items.ptr, decoder.idat_list.items.len);

    const line_width = if (bits_per_line % 8 == 0) bits_per_line / 8 + 1 else (bits_per_line / 8 + 1) + 1;

    for (0..decoder.IHDR.height) |i| {
        switch (uncompressed_buf[i * line_width]) {
            1 => unfliter.unFilterSub(uncompressed_buf, i, line_width, decoder.sample_size),
            2 => unfliter.unFilterUp(uncompressed_buf, i, line_width, decoder.sample_size),
            3 => unfliter.unFilterAverage(uncompressed_buf, i, line_width, decoder.sample_size),
            4 => unfliter.unFilterPaeth(uncompressed_buf, i, line_width, decoder.sample_size),
            else => {},
        }
        const start_pos = i * line_width + 1;
        const end_pos = start_pos + line_width - 1;
        try pixel_list.appendSlice(uncompressed_buf[start_pos..end_pos]);
    }
    decoder.pixel_buf = pixel_list.items;
}

// CRITICAL CHUNKS

pub fn handleIHDR(decoder: *Decoder) !void {
    const width: u32 =
        @as(u32, decoder.original_img_buffer[16]) << 24 |
        @as(u32, decoder.original_img_buffer[17]) << 16 |
        @as(u32, decoder.original_img_buffer[18]) << 8 |
        @as(u32, decoder.original_img_buffer[19]);
    const height: u32 =
        @as(u32, decoder.original_img_buffer[20]) << 24 |
        @as(u32, decoder.original_img_buffer[21]) << 16 |
        @as(u32, decoder.original_img_buffer[22]) << 8 |
        @as(u32, decoder.original_img_buffer[23]);

    const bit_depth: u8 = decoder.original_img_buffer[24];
    const color_type: u8 = decoder.original_img_buffer[25];
    const compression_method: u8 = decoder.original_img_buffer[26];
    const filter_method: u8 = decoder.original_img_buffer[27];
    const interlace_method: u8 = decoder.original_img_buffer[28];

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

    decoder.IHDR = .{
        .height = height,
        .width = width,
        .bit_depth = bit_depth,
        .color_type = color_type,
        .compression_method = compression_method,
        .filter_method = filter_method,
        .interlace_method = interlace_method,
    };
    decoder.sample_size = sample_size;
}

/// appends each IDAT chunk data block to the list of IDAT data to handle cases of > 1 IDAT chunks
pub fn handleIDAT(decoder: *Decoder, offset: u32, data_length: u32) !void {
    const end_pos = offset + data_length;
    const compressed_buf = decoder.original_img_buffer[offset..end_pos];
    _ = try decoder.idat_list.appendSlice(compressed_buf);
}

pub fn handlePLTE(decoder: *Decoder, offset: u32, data_length: u32) !void {
    if (data_length % 3 != 0) return PNGReadError.PLTENotDivisibleByThree;
    const end_pos = data_length + offset;

    decoder.PLTE = .{
        .sections = decoder.original_img_buffer[offset..end_pos],
    };
}

// TRANSPARENCY

pub fn handletRNS(decoder: *Decoder, offset: u32, data_length: u32) !void {
    var grey_sample: ?u16 = null;
    var red_sample: ?u16 = null;
    var green_sample: ?u16 = null;
    var blue_sample: ?u16 = null;
    var alphas: ?[]u8 = null;

    switch (decoder.IHDR.color_type) {
        0 => {
            grey_sample =
                @as(u16, decoder.original_img_buffer[offset]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 1]);
        },
        2 => {
            red_sample =
                @as(u16, decoder.original_img_buffer[offset]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 1]);
            green_sample =
                @as(u16, decoder.original_img_buffer[offset + 2]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 3]);
            blue_sample =
                @as(u16, decoder.original_img_buffer[offset + 4]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 5]);
        },

        3 => {
            alphas = try decoder.uncompressed_allocator.alloc(u8, data_length);
            for (0..data_length) |i| {
                alphas.?[i] = decoder.original_img_buffer[offset + i];
            }
        },
        else => unreachable,
    }
    decoder.tRNS = .{
        .grey_sample = grey_sample,
        .red_sample = red_sample,
        .green_sample = green_sample,
        .blue_sample = blue_sample,
        .alphas = alphas,
    };
}

// TEXTUAL INFORMATION

pub fn handletEXt(decoder: *Decoder, offset: u32, data_length: u32) !void {
    var keyword: []u8 = undefined;
    var text: []u8 = undefined;

    const end_pos = offset + data_length;
    const null_pos = std.mem.indexOfScalar(u8, decoder.original_img_buffer[offset..end_pos], 0).?;
    const keyword_end = offset + null_pos;
    keyword = decoder.original_img_buffer[offset..keyword_end];
    const text_start = offset + null_pos + 1;
    const text_end = offset + data_length;
    text = decoder.original_img_buffer[text_start..text_end];

    try decoder.tEXt_list.?.append(.{
        .keyword = keyword,
        .text = text,
    });
}

pub fn handlezTXt(decoder: *Decoder, offset: u32, data_length: u32) !void {
    var keyword: []u8 = undefined;
    var compression_method: u8 = undefined;

    // check out https://www.zlib.net/zlib_how.html
    const chunk: c_uint = 1024;
    var temp_out_list = std.ArrayList(u8).init(decoder.uncompressed_allocator);
    var temp_out_buf: [chunk]u8 = undefined;
    var zlib_ret: c_int = undefined;
    var decompressed_count: c_uint = undefined;

    const end_pos = offset + data_length;
    // safe downcast. chunk size always < 2^31
    const null_pos = @as(u32, @intCast(std.mem.indexOfScalar(u8, decoder.original_img_buffer[offset..end_pos], 0).?));
    const keyword_end = null_pos + offset;

    keyword = decoder.original_img_buffer[offset..keyword_end];
    compression_method = decoder.original_img_buffer[keyword_end + 1];
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
    strm.next_in = decoder.original_img_buffer[text_start..text_end].ptr;
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
    try decoder.zTXt_list.?.append(.{
        .keyword = keyword,
        .compression_method = compression_method,
        .text = temp_out_list.items,
    });
}

pub fn handleiTXt(decoder: *Decoder, offset: u32, data_length: u32) !void {
    var keyword: []u8 = undefined;
    var compression_flag: u8 = undefined;
    var compression_method: u8 = undefined;
    var language_tag: []u8 = undefined;
    var translated_keyword: []u8 = undefined;
    var text: []u8 = undefined;

    const end_pos = offset + data_length;
    const null_one = @as(u32, @intCast(std.mem.indexOfScalar(u8, decoder.original_img_buffer[offset..end_pos], 0).?));
    const keyword_end = offset + null_one;
    keyword = decoder.original_img_buffer[offset..keyword_end];
    compression_flag = decoder.original_img_buffer[offset + null_one + 1];
    compression_method = decoder.original_img_buffer[offset + null_one + 2];

    const language_tag_start_abs = offset + null_one + 3;
    if (compression_method != 0) return PNGReadError.InvalidCompressionMethod;
    const null_two = @as(u32, @intCast(std.mem.indexOfScalar(u8, decoder.original_img_buffer[language_tag_start_abs..end_pos], 0).?));
    const language_tag_end_abs = language_tag_start_abs + null_two;
    language_tag = decoder.original_img_buffer[language_tag_start_abs..language_tag_end_abs];

    const translated_keyword_start_abs = language_tag_end_abs + 1;
    const null_three = @as(u32, @intCast(std.mem.indexOfScalar(u8, decoder.original_img_buffer[translated_keyword_start_abs..end_pos], 0).?));
    const translated_keyword_end_abs = translated_keyword_start_abs + null_three;

    translated_keyword = decoder.original_img_buffer[translated_keyword_start_abs..translated_keyword_end_abs];

    const text_start_abs = translated_keyword_end_abs + 1;
    if (compression_flag == 0) {
        text = decoder.original_img_buffer[text_start_abs..end_pos];
        try decoder.iTXt_list.?.append(.{
            .keyword = keyword,
            .compression_flag = compression_flag,
            .compression_method = compression_method,
            .language_tag = language_tag,
            .translated_keyword = translated_keyword,
            .text = text,
        });
        return;
    }

    const chunk: c_uint = 1024;
    var temp_out_list = std.ArrayList(u8).init(decoder.uncompressed_allocator);
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

    strm.avail_in = @as(c_uint, @intCast(end_pos)) - text_start_abs;
    strm.next_in = decoder.original_img_buffer[text_start_abs..end_pos].ptr;
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

    try decoder.iTXt_list.?.append(.{
        .keyword = keyword,
        .compression_flag = compression_flag,
        .compression_method = compression_method,
        .language_tag = language_tag,
        .translated_keyword = translated_keyword,
        .text = temp_out_list.items,
    });
}

// MISCELLANEOUS INFORMATION

pub fn handlebKGD(decoder: *Decoder, offset: u32) void {
    var greyscale: ?u16 = null;
    var red: ?u16 = null;
    var green: ?u16 = null;
    var blue: ?u16 = null;
    var palette_index: ?u8 = null;

    switch (decoder.IHDR.color_type) {
        0, 4 => {
            greyscale =
                @as(u16, decoder.original_img_buffer[offset]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 1]);
        },
        2, 6 => {
            red =
                @as(u16, decoder.original_img_buffer[offset]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 1]);
            green =
                @as(u16, decoder.original_img_buffer[offset + 2]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 3]);

            blue =
                @as(u16, decoder.original_img_buffer[offset + 4]) << 8 |
                @as(u16, decoder.original_img_buffer[offset + 5]);
        },

        3 => {
            palette_index = decoder.original_img_buffer[offset];
        },
        else => unreachable,
    }

    decoder.bKGD = .{
        .greyscale = greyscale,
        .red = red,
        .green = green,
        .blue = blue,
        .palette_index = palette_index,
    };
}

pub fn handlehIST(decoder: *Decoder, offset: u32, data_length: u32) !void {
    var hist_len: u32 = undefined;

    if (data_length % 2 == 0) {
        hist_len = data_length / 2;
    } else {
        return PNGReadError.hISTNotValidU16Slice;
    }
    var frequencies_slice = try decoder.uncompressed_allocator.alloc(u16, hist_len);

    for (0..hist_len) |i| {
        var frequency: u16 =
            @as(u16, decoder.original_img_buffer[offset + i]) << 8 |
            @as(u16, decoder.original_img_buffer[offset + i + 1]);
        frequencies_slice[i] = frequency;
    }

    decoder.hIST = .{
        .frequencies = frequencies_slice,
    };
}

pub fn handlepHYs(decoder: *Decoder, offset: u32) void {
    const ppu_x: u32 =
        @as(u32, decoder.original_img_buffer[offset]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 3]);
    const ppu_y: u32 =
        @as(u32, decoder.original_img_buffer[offset + 4]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 5]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 6]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 7]);
    decoder.pHYS = .{
        .ppu_x = ppu_x,
        .ppu_y = ppu_y,
        .unit_specifier = decoder.original_img_buffer[offset + 8],
    };
}

pub fn handlesPLT(decoder: *Decoder, offset: u32, data_length: u32) !void {
    const end_pos = data_length + offset;
    const null_one = std.mem.indexOfScalar(u8, decoder.original_img_buffer[offset..end_pos], 0).?;
    const null_one_abs = offset + null_one;
    const palette_name = decoder.original_img_buffer[offset..null_one_abs];

    const sample_depth = decoder.original_img_buffer[null_one_abs + 1];

    if (sample_depth != 8 and sample_depth != 16) return PNGReadError.InvalidsPLTSampleDeth;
    const palette_start_abs = null_one_abs + 2;
    var palette_length_bytes = end_pos - palette_start_abs;

    if (sample_depth == 8 and palette_length_bytes % 6 != 0) return PNGReadError.InvalidsPLT;
    if (sample_depth == 16 and palette_length_bytes % 10 != 0) return PNGReadError.InvalidsPLT;

    // # of palette structs to allocate
    const palette_size = if (sample_depth == 8) palette_length_bytes / 6 else palette_length_bytes / 10;
    var palette_slice = try decoder.uncompressed_allocator.alloc(chunks.splt_palette, palette_size);

    var i: u32 = 0;
    var byte_offset: u32 = 0;

    if (sample_depth == 8) {
        while (i < palette_size) {
            byte_offset = i * 6;
            palette_slice[i].red_8 = decoder.original_img_buffer[byte_offset];
            palette_slice[i].green_8 = decoder.original_img_buffer[byte_offset + 1];
            palette_slice[i].blue_8 = decoder.original_img_buffer[byte_offset + 2];
            palette_slice[i].alpha_8 = decoder.original_img_buffer[byte_offset + 3];
            palette_slice[i].red_16 = null;
            palette_slice[i].green_16 = null;
            palette_slice[i].blue_16 = null;
            palette_slice[i].alpha_16 = null;
            palette_slice[i].frequency =
                @as(u16, decoder.original_img_buffer[byte_offset + 4]) << 8 |
                @as(u16, decoder.original_img_buffer[byte_offset + 5]);

            i += 1;
        }
    } else {
        while (i < palette_size) {
            byte_offset = i * 10;
            palette_slice[i].red_16 =
                @as(u16, decoder.original_img_buffer[byte_offset]) << 8 |
                @as(u16, decoder.original_img_buffer[byte_offset + 1]);
            palette_slice[i].green_16 =
                @as(u16, decoder.original_img_buffer[byte_offset + 2]) << 8 |
                @as(u16, decoder.original_img_buffer[byte_offset + 3]);
            palette_slice[i].blue_16 =
                @as(u16, decoder.original_img_buffer[byte_offset + 4]) << 8 |
                @as(u16, decoder.original_img_buffer[byte_offset + 5]);
            palette_slice[i].alpha_16 =
                @as(u16, decoder.original_img_buffer[byte_offset + 6]) << 8 |
                @as(u16, decoder.original_img_buffer[byte_offset + 7]);
            palette_slice[i].frequency =
                @as(u16, decoder.original_img_buffer[byte_offset + 8]) << 8 |
                @as(u16, decoder.original_img_buffer[byte_offset + 9]);
            palette_slice[i].red_8 = null;
            palette_slice[i].green_8 = null;
            palette_slice[i].blue_8 = null;
            palette_slice[i].alpha_8 = null;
            i += 1;
        }
    }

    try decoder.sPLT_list.?.append(.{
        .palette_name = palette_name,
        .sample_depth = sample_depth,
        .palette = palette_slice,
    });
}

pub fn handleeXIf(decoder: *Decoder, offset: u32, data_length: u32) void {
    const end_pos = offset + data_length;
    decoder.eXIf = .{
        .data = decoder.original_img_buffer[offset..end_pos],
    };
}

// TIME

pub fn handletIME(decoder: *Decoder, offset: u32) void {
    const year: u16 = @as(u16, decoder.original_img_buffer[offset]) << 8 |
        @as(u16, decoder.original_img_buffer[offset + 1]);

    decoder.tIME = .{
        .year = year,
        .month = decoder.original_img_buffer[offset + 2],
        .day = decoder.original_img_buffer[offset + 3],
        .hour = decoder.original_img_buffer[offset + 4],
        .minute = decoder.original_img_buffer[offset + 5],
        .second = decoder.original_img_buffer[offset + 6],
    };
}

// COLOR SPACE

pub fn handlecHRM(decoder: *Decoder, offset: u32) void {
    const white_point_x: u32 =
        @as(u32, decoder.original_img_buffer[offset]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 3]);
    const white_point_y: u32 =
        @as(u32, decoder.original_img_buffer[offset + 4]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 5]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 6]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 7]);
    const red_x: u32 =
        @as(u32, decoder.original_img_buffer[offset + 8]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 9]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 10]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 11]);
    const red_y: u32 =
        @as(u32, decoder.original_img_buffer[offset + 12]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 13]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 14]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 15]);
    const green_x: u32 =
        @as(u32, decoder.original_img_buffer[offset + 16]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 17]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 18]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 19]);
    const green_y: u32 =
        @as(u32, decoder.original_img_buffer[offset + 20]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 21]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 22]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 23]);
    const blue_x: u32 =
        @as(u32, decoder.original_img_buffer[offset + 24]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 25]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 26]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 27]);
    const blue_y: u32 =
        @as(u32, decoder.original_img_buffer[offset + 28]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 29]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 30]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 31]);

    decoder.cHRM = .{
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

pub fn handlegAMA(decoder: *Decoder, offset: u32) void {
    const gama: u32 =
        @as(u32, decoder.original_img_buffer[offset]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 3]);

    decoder.gAMA = .{
        .image_gama = gama,
    };
}

pub fn handleiCCP(decoder: *Decoder, offset: u32, data_length: u32) !void {
    const end_pos = data_length + offset;
    const null_pos = @as(u32, @intCast(std.mem.indexOfScalar(u8, decoder.original_img_buffer[offset..end_pos], 0).?));

    const profile_name_end_abs = offset + null_pos;
    const profile_name = decoder.original_img_buffer[offset..profile_name_end_abs];
    const compression_method = decoder.original_img_buffer[profile_name_end_abs + 1];
    if (compression_method != 0) return PNGReadError.InvalidCompressionMethod;

    const profile_start = profile_name_end_abs + 2;
    const chunk: c_uint = 10_000;
    var temp_out_list = std.ArrayList(u8).init(decoder.uncompressed_allocator);
    var temp_out_buf: [chunk]u8 = undefined;
    var zlib_ret: c_int = undefined;
    var decompressed_count: c_uint = undefined;
    var strm: zlib.z_stream = .{
        .avail_in = 0,
        .next_in = null,
        .zalloc = null,
        .zfree = null,
        .@"opaque" = null,
    };
    zlib_ret = zlib.inflateInit(&strm);

    if (zlib_ret != zlib.Z_OK) return PNGReadError.ZlibInflateInitError;

    strm.avail_in = @as(c_uint, @intCast(end_pos)) - profile_start;
    strm.next_in = decoder.original_img_buffer[profile_start..end_pos].ptr;
    while (strm.avail_out == 0 or zlib_ret != zlib.Z_STREAM_END) {
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
    // of decompressed ICC profile data
    temp_out_list.shrinkAndFree(temp_out_list.items.len);
    _ = zlib.inflateEnd(&strm);

    decoder.iCCP = .{
        .profile_name = profile_name,
        .compression_method = compression_method,
        .profile = temp_out_list.items,
    };
}

pub fn handlesBIT(decoder: *Decoder, offset: u32) void {
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

    switch (decoder.IHDR.color_type) {
        0 => sig_grey_bits_t0 = decoder.original_img_buffer[offset],
        2, 3 => {
            sig_red_bits_t23 = decoder.original_img_buffer[offset];
            sig_green_bits_t23 = decoder.original_img_buffer[offset + 1];
            sig_blue_bits_t23 = decoder.original_img_buffer[offset + 2];
        },
        4 => {
            sig_grey_bits_t4 = decoder.original_img_buffer[offset];
            sig_alpha_bits_t4 = decoder.original_img_buffer[offset + 1];
        },
        6 => {
            sig_red_bits_t6 = decoder.original_img_buffer[offset];
            sig_green_bits_t6 = decoder.original_img_buffer[offset + 1];
            sig_blue_bits_t6 = decoder.original_img_buffer[offset + 2];
            sig_alpha_bits_t6 = decoder.original_img_buffer[offset + 3];
        },
        else => unreachable,
    }

    decoder.sBIT = .{
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
pub fn handlesRGB(decoder: *Decoder, offset: u32) void {
    decoder.sRGB = .{
        .rendering_intent = decoder.original_img_buffer[offset],
    };
}

pub fn handlecICP(decoder: *Decoder, offset: u32) !void {
    const matrix_coefficients = decoder.original_img_buffer[offset + 2];
    if (matrix_coefficients != 0) return PNGReadError.InvalidcICPMatrixCoefficient;

    decoder.cICP = .{
        .color_primaries = decoder.original_img_buffer[offset],
        .transfer_function = decoder.original_img_buffer[offset + 1],
        .matrix_coefficients = matrix_coefficients,
        .video_frf = decoder.original_img_buffer[offset + 3],
    };
}

pub fn handlemDCv(decoder: *Decoder, offset: u32) void {
    const dcp_end_abs = offset + 12;
    const mastering_dcp = decoder.original_img_buffer[offset..dcp_end_abs];
    const mastering_dwpc: u32 =
        @as(u32, decoder.original_img_buffer[offset + 12]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 13]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 14]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 15]);
    const mastering_dmaxl: u32 =
        @as(u32, decoder.original_img_buffer[offset + 16]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 17]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 18]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 19]);
    const mastering_dminl: u32 =
        @as(u32, decoder.original_img_buffer[offset + 20]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 21]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 22]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 23]);
    decoder.mDCv = .{
        .mastering_dcp = mastering_dcp,
        .mastering_dwpc = mastering_dwpc,
        .mastering_dmaxl = mastering_dmaxl,
        .mastering_dminl = mastering_dminl,
    };
}

pub fn handlecLLi(decoder: *Decoder, offset: u32) void {
    const max_cll: u32 =
        @as(u32, decoder.original_img_buffer[offset]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 3]);
    const max_fall: u32 =
        @as(u32, decoder.original_img_buffer[offset + 4]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 5]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 6]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 7]);
    decoder.cLLi = .{
        .max_cll = max_cll,
        .max_fall = max_fall,
    };
}

// ANIMATION INFORMATION

pub fn handleacTL(decoder: *Decoder, offset: u32) void {
    const num_frames: u32 =
        @as(u32, decoder.original_img_buffer[offset]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 3]);
    const num_plays: u32 =
        @as(u32, decoder.original_img_buffer[offset + 4]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 5]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 6]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 7]);
    decoder.acTL = .{
        .num_frames = num_frames,
        .num_plays = num_plays,
    };
}

pub fn handlefcTL(decoder: *Decoder, offset: u32) void {
    const sequence_number: u32 =
        @as(u32, decoder.original_img_buffer[offset]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 1]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 2]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 3]);
    const width: u32 =
        @as(u32, decoder.original_img_buffer[offset + 4]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 5]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 6]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 7]);
    const height: u32 =
        @as(u32, decoder.original_img_buffer[offset + 8]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 9]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 10]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 11]);
    const x_offset: u32 =
        @as(u32, decoder.original_img_buffer[offset + 12]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 13]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 14]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 15]);
    const y_offset: u32 =
        @as(u32, decoder.original_img_buffer[offset + 16]) << 24 |
        @as(u32, decoder.original_img_buffer[offset + 17]) << 16 |
        @as(u32, decoder.original_img_buffer[offset + 18]) << 8 |
        @as(u32, decoder.original_img_buffer[offset + 19]);
    const delay_num: u16 =
        @as(u16, decoder.original_img_buffer[offset + 20]) << 8 |
        @as(u16, decoder.original_img_buffer[offset + 21]);
    const delay_den: u16 =
        @as(u16, decoder.original_img_buffer[offset + 22]) << 8 |
        @as(u16, decoder.original_img_buffer[offset + 23]);

    decoder.fcTL = .{
        .sequence_number = sequence_number,
        .width = width,
        .height = height,
        .x_offset = x_offset,
        .y_offset = y_offset,
        .delay_num = delay_num,
        .delay_den = delay_den,
        .dispose_op = decoder.original_img_buffer[offset + 24],
        .blend_op = decoder.original_img_buffer[offset + 25],
    };
}
