const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color image with 13 signigicant bits" {
    const file_path = "samples/sig_bits/cs3n2c16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .sBIT = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 6144);
    try testing.expect(image.IHDR.?.bit_depth == 16);

    try testing.expect(image.sBIT.?.sig_red_bits_t23 == 13);
    try testing.expect(image.sBIT.?.sig_green_bits_t23 == 13);
    try testing.expect(image.sBIT.?.sig_blue_bits_t23 == 13);

    try testing.expect(image.sBIT.?.sig_grey_bits_t0 == null);
    try testing.expect(image.sBIT.?.sig_grey_bits_t4 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t4 == null);

    try testing.expect(image.sBIT.?.sig_red_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_green_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_blue_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t6 == null);
}

test "decode paletted image with 3 signigicant bits" {
    const file_path = "samples/sig_bits/cs3n3p08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .sBIT = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);
    try testing.expect(image.IHDR.?.bit_depth == 8);

    try testing.expect(image.sBIT.?.sig_red_bits_t23 == 3);
    try testing.expect(image.sBIT.?.sig_green_bits_t23 == 3);
    try testing.expect(image.sBIT.?.sig_blue_bits_t23 == 3);

    try testing.expect(image.sBIT.?.sig_grey_bits_t0 == null);
    try testing.expect(image.sBIT.?.sig_grey_bits_t4 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t4 == null);

    try testing.expect(image.sBIT.?.sig_red_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_green_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_blue_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t6 == null);
}

test "decode color image with 5 signigicant bits" {
    const file_path = "samples/sig_bits/cs5n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .sBIT = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 3072);
    try testing.expect(image.IHDR.?.bit_depth == 8);

    try testing.expect(image.sBIT.?.sig_red_bits_t23 == 5);
    try testing.expect(image.sBIT.?.sig_green_bits_t23 == 5);
    try testing.expect(image.sBIT.?.sig_blue_bits_t23 == 5);

    try testing.expect(image.sBIT.?.sig_grey_bits_t0 == null);
    try testing.expect(image.sBIT.?.sig_grey_bits_t4 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t4 == null);

    try testing.expect(image.sBIT.?.sig_red_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_green_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_blue_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t6 == null);
}

test "decode paletted image with 5 signigicant bits" {
    const file_path = "samples/sig_bits/cs5n3p08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .sBIT = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);
    try testing.expect(image.IHDR.?.bit_depth == 8);

    try testing.expect(image.sBIT.?.sig_red_bits_t23 == 5);
    try testing.expect(image.sBIT.?.sig_green_bits_t23 == 5);
    try testing.expect(image.sBIT.?.sig_blue_bits_t23 == 5);

    try testing.expect(image.sBIT.?.sig_grey_bits_t0 == null);
    try testing.expect(image.sBIT.?.sig_grey_bits_t4 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t4 == null);

    try testing.expect(image.sBIT.?.sig_red_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_green_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_blue_bits_t6 == null);
    try testing.expect(image.sBIT.?.sig_alpha_bits_t6 == null);
}
