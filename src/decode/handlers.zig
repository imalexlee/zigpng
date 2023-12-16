const std = @import("std");
const png_decoder = @import("decoder.zig");
const Decoder = png_decoder.pngDecoder();
const PNGReadError = png_decoder.PNGReadError;
const zlib = @cImport(@cInclude("zlib.h"));

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

/// appends each IDAT chunk data block to the list of IDAT data in cases of > 1 IDAT chunks
pub fn handleIDAT(decoder: *Decoder, data_offset: u32, data_length: u32) !void {
    const end_pos = data_offset + data_length;
    const compressed_buf = decoder.original_img_buffer[data_offset..end_pos];
    _ = try decoder.idat_list.appendSlice(compressed_buf);
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
    // of decompressed text data
    temp_out_list.shrinkAndFree(temp_out_list.items.len);
    _ = zlib.inflateEnd(&strm);

    decoder.iCCP = .{
        .profile_name = profile_name,
        .compression_method = compression_method,
        .profile = temp_out_list.items,
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
