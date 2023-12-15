const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode greyscale image last modified at 01-jan-2000 12:34:56" {
    const file_path = "samples/time/cm0n0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .tIME = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 512);
    try testing.expect(image.IHDR.bit_depth == 4);

    try testing.expect(image.tIME.?.year == 2000);
    try testing.expect(image.tIME.?.month == 1);
    try testing.expect(image.tIME.?.day == 1);
    try testing.expect(image.tIME.?.hour == 12);
    try testing.expect(image.tIME.?.minute == 34);
    try testing.expect(image.tIME.?.second == 56);
}

test "decode greyscale image last modified at 01-jan-1970 00:00:00" {
    const file_path = "samples/time/cm7n0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .tIME = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 512);
    try testing.expect(image.IHDR.bit_depth == 4);

    try testing.expect(image.tIME.?.year == 1970);
    try testing.expect(image.tIME.?.month == 1);
    try testing.expect(image.tIME.?.day == 1);
    try testing.expect(image.tIME.?.hour == 0);
    try testing.expect(image.tIME.?.minute == 0);
    try testing.expect(image.tIME.?.second == 0);
}

test "decode greyscale image last modified at 31-dec-1999 23:59:59" {
    const file_path = "samples/time/cm9n0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .tIME = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 32);
    try testing.expect(image.IHDR.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 512);
    try testing.expect(image.IHDR.bit_depth == 4);

    try testing.expect(image.tIME.?.year == 1999);
    try testing.expect(image.tIME.?.month == 12);
    try testing.expect(image.tIME.?.day == 31);
    try testing.expect(image.tIME.?.hour == 23);
    try testing.expect(image.tIME.?.minute == 59);
    try testing.expect(image.tIME.?.second == 59);
}
