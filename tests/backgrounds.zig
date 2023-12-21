const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color image with white background" {
    const file_path = "samples/backgrounds/color/bgwn6a08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .bKGD = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 4);
    try testing.expect(image.pixel_buf.len == 4096);

    try testing.expect(image.bKGD.?.greyscale == null);
    try testing.expect(image.bKGD.?.palette_index == null);
    try testing.expect(image.bKGD.?.red == 255);
    try testing.expect(image.bKGD.?.green == 255);
    try testing.expect(image.bKGD.?.blue == 255);
}

test "decode color image with yellow background" {
    const file_path = "samples/backgrounds/color/bgyn6a16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .bKGD = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 4);
    try testing.expect(image.pixel_buf.len == 8192);

    try testing.expect(image.bKGD.?.greyscale == null);
    try testing.expect(image.bKGD.?.palette_index == null);
    try testing.expect(image.bKGD.?.red == 65535);
    try testing.expect(image.bKGD.?.green == 65535);
    try testing.expect(image.bKGD.?.blue == 0);
}

test "decode greyscale image with black background" {
    const file_path = "samples/backgrounds/greyscale/bgbn4a08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .bKGD = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 2);
    try testing.expect(image.pixel_buf.len == 2048);

    try testing.expect(image.bKGD.?.greyscale == 0);
    try testing.expect(image.bKGD.?.palette_index == null);
    try testing.expect(image.bKGD.?.red == null);
    try testing.expect(image.bKGD.?.green == null);
    try testing.expect(image.bKGD.?.blue == null);
}

test "decode greyscale image with grey background" {
    const file_path = "samples/backgrounds/greyscale/bggn4a16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .bKGD = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 2);
    try testing.expect(image.pixel_buf.len == 4096);
    try testing.expect(image.bKGD.?.greyscale == 43908);
    try testing.expect(image.bKGD.?.palette_index == null);
    try testing.expect(image.bKGD.?.red == null);
    try testing.expect(image.bKGD.?.green == null);
    try testing.expect(image.bKGD.?.blue == null);
}
