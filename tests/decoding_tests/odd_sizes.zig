const std = @import("std");
const png_decoder = @import("../../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode 1 x 1 image" {
    const file_path = "samples/odd_sizes/s01n3p01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 1);
    try testing.expect(image.IHDR.height == 1);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1);
    try testing.expect(image.IHDR.bit_depth == 1);
    try testing.expect(image.PLTE.?.sections[0] == 0);
    try testing.expect(image.PLTE.?.sections[1] == 0);
    try testing.expect(image.PLTE.?.sections[2] == 255);
}

test "decode 2 x 2 image" {
    const file_path = "samples/odd_sizes/s02n3p01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 2);
    try testing.expect(image.IHDR.height == 2);
    try testing.expect(image.pixel_buf.len == 2);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 1);
    try testing.expect(image.PLTE.?.sections[0] == 0);
    try testing.expect(image.PLTE.?.sections[1] == 255);
    try testing.expect(image.PLTE.?.sections[2] == 255);
}
