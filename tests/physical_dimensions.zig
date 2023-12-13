const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color image with 8 x 32 tall dimensions" {
    const file_path = "samples/physical_dimensions/cdfn2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .pHYS = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 8);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 768);
    try testing.expect(image.IHDR.bit_depth == 8);

    try testing.expect(image.pHYS.?.ppu_x == 1);
    try testing.expect(image.pHYS.?.ppu_y == 4);
    try testing.expect(image.pHYS.?.unit_specifier == 0);
}

test "decode color image with 32 x 8 flat dimensions" {
    const file_path = "samples/physical_dimensions/cdhn2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .pHYS = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 8);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 768);
    try testing.expect(image.IHDR.bit_depth == 8);

    try testing.expect(image.pHYS.?.ppu_x == 4);
    try testing.expect(image.pHYS.?.ppu_y == 1);
    try testing.expect(image.pHYS.?.unit_specifier == 0);
}

test "decode color image with 8 x 8 square dimensions" {
    const file_path = "samples/physical_dimensions/cdsn2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .pHYS = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 8);
    try testing.expect(image.IHDR.height == 8);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 192);
    try testing.expect(image.IHDR.bit_depth == 8);

    try testing.expect(image.pHYS.?.ppu_x == 1);
    try testing.expect(image.pHYS.?.ppu_y == 1);
    try testing.expect(image.pHYS.?.unit_specifier == 0);
}

test "decode color image with 3.2cm physical dimensions. 1000 pixels per 1 meter" {
    const file_path = "samples/physical_dimensions/cdun2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .pHYS = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 3072);
    try testing.expect(image.IHDR.bit_depth == 8);

    try testing.expect(image.pHYS.?.ppu_x == 1000);
    try testing.expect(image.pHYS.?.ppu_y == 1000);
    try testing.expect(image.pHYS.?.unit_specifier == 1);
}
