const std = @import("std");
const png_decoder = @import("../../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode filter type 0 greyscale image" {
    const file_path = "samples/filtering/greyscale/f00n0g08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
}

test "decode filter type 1 greyscale image" {
    const file_path = "samples/filtering/greyscale/f01n0g08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
}

test "decode filter type 2 greyscale image" {
    const file_path = "samples/filtering/greyscale/f02n0g08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
}

test "decode filter type 3 greyscale image" {
    const file_path = "samples/filtering/greyscale/f03n0g08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
}

test "decode multiple filter type greyscale image" {
    const file_path = "samples/filtering/greyscale/f99n0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator);
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readChunks();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
}
