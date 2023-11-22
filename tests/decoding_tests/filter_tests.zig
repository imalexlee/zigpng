const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode filter type 0 color image" {
    const file_path = "samples/filtering/color/f00n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    var pixel_length = image.IHDR.height * image.IHDR.width * image.bytes_per_pix + image.IHDR.height;

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.uncompressed_len == pixel_length);
    try testing.expect(image.uncompressed_buf.len == image.uncompressed_len);
}

test "decode filter type 1 color image" {
    const file_path = "samples/filtering/color/f01n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    var pixel_length = image.IHDR.height * image.IHDR.width * image.bytes_per_pix + image.IHDR.height;

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.uncompressed_len == pixel_length);
    try testing.expect(image.uncompressed_buf.len == image.uncompressed_len);
}

test "decode filter type 2 color image" {
    const file_path = "samples/filtering/color/f02n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    var pixel_length = image.IHDR.height * image.IHDR.width * image.bytes_per_pix + image.IHDR.height;

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.uncompressed_len == pixel_length);
    try testing.expect(image.uncompressed_buf.len == image.uncompressed_len);
}

test "decode filter type 3 color image" {
    const file_path = "samples/filtering/color/f03n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    var pixel_length = image.IHDR.height * image.IHDR.width * image.bytes_per_pix + image.IHDR.height;

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.uncompressed_len == pixel_length);
    try testing.expect(image.uncompressed_buf.len == image.uncompressed_len);
}
