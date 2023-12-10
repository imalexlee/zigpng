const std = @import("std");
const png_decoder = @import("../../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode greyscale image with 1 idat" {
    const file_path = "samples/idat_variations/greyscale/oi1n0g16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 2048);
    try testing.expect(image.IHDR.bit_depth == 16);
}
test "decode greyscale image with 2 idats" {
    const file_path = "samples/idat_variations/greyscale/oi2n0g16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 2048);
    try testing.expect(image.IHDR.bit_depth == 16);
}

test "decode greyscale image with 4 unequal length idat chunks" {
    const file_path = "samples/idat_variations/greyscale/oi4n0g16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 2048);
    try testing.expect(image.IHDR.bit_depth == 16);
}
test "decode greyscale image with all idat chunks having a length of 1" {
    const file_path = "samples/idat_variations/greyscale/oi9n0g16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 2048);
    try testing.expect(image.IHDR.bit_depth == 16);
}
