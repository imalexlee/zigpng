const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color image with chromaticities w:0.3127,0.3290 r:0.64,0.33 g:0.30,0.60 b:0.15,0.06" {
    const file_path = "samples/chromaticities/ccwn2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .cHRM = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 3072);

    try testing.expect(image.cHRM.?.white_point_x == 31270);
    try testing.expect(image.cHRM.?.white_point_y == 32900);
    try testing.expect(image.cHRM.?.red_x == 64000);
    try testing.expect(image.cHRM.?.red_y == 33000);
    try testing.expect(image.cHRM.?.green_x == 30000);
    try testing.expect(image.cHRM.?.green_y == 60000);
    try testing.expect(image.cHRM.?.blue_x == 15000);
    try testing.expect(image.cHRM.?.blue_y == 6000);
}

test "decode paletted image with chromaticities w:0.3127,0.3290 r:0.64,0.33 g:0.30,0.60 b:0.15,0.06" {
    const file_path = "samples/chromaticities/ccwn3p08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .cHRM = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);

    try testing.expect(image.cHRM.?.white_point_x == 31270);
    try testing.expect(image.cHRM.?.white_point_y == 32900);
    try testing.expect(image.cHRM.?.red_x == 64000);
    try testing.expect(image.cHRM.?.red_y == 33000);
    try testing.expect(image.cHRM.?.green_x == 30000);
    try testing.expect(image.cHRM.?.green_y == 60000);
    try testing.expect(image.cHRM.?.blue_x == 15000);
    try testing.expect(image.cHRM.?.blue_y == 6000);
}
