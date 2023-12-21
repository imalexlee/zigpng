const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode greyscale image with a gama of 0.35" {
    const file_path = "samples/gama/g03n0g16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .gAMA = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 2048);
    try testing.expect(image.IHDR.?.bit_depth == 16);
    try testing.expect(image.gAMA.?.image_gama == 35000);
}

test "decode color image with a gama of 0.35" {
    const file_path = "samples/gama/g03n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .gAMA = true,
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
    try testing.expect(image.gAMA.?.image_gama == 35000);
}

test "decode paletted image with a gama of 2.5" {
    const file_path = "samples/gama/g25n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .gAMA = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 512);
    try testing.expect(image.IHDR.?.bit_depth == 4);
    try testing.expect(image.gAMA.?.image_gama == 250000);
}
