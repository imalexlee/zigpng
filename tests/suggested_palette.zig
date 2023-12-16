const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color image with a 1 byte suggested palette depth" {
    const file_path = "samples/suggested_palette/ps1n2c16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .sPLT = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 6144);
    try testing.expect(image.IHDR.bit_depth == 16);

    try testing.expect(image.sPLT_list.?.items[0].sample_depth == 8);

    try testing.expect(image.sPLT_list.?.items[0].palette[0].red_8 != null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].green_8 != null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].blue_8 != null);

    try testing.expect(image.sPLT_list.?.items[0].palette[0].red_16 == null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].green_16 == null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].blue_16 == null);
    try testing.expectEqualStrings("six-cube", image.sPLT_list.?.items[0].palette_name);
}

test "decode color image with a 2 byte suggested palette depth" {
    const file_path = "samples/suggested_palette/ps2n2c16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .sPLT = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 6144);
    try testing.expect(image.IHDR.bit_depth == 16);

    try testing.expect(image.sPLT_list.?.items[0].sample_depth == 16);

    try testing.expect(image.sPLT_list.?.items[0].palette[0].red_16 != null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].green_16 != null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].blue_16 != null);

    try testing.expect(image.sPLT_list.?.items[0].palette[0].red_8 == null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].green_8 == null);
    try testing.expect(image.sPLT_list.?.items[0].palette[0].blue_8 == null);
    try testing.expectEqualStrings("six-cube", image.sPLT_list.?.items[0].palette_name);
}
