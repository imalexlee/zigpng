const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
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
test "decode 3 x 3 image" {
    const file_path = "samples/odd_sizes/s03n3p01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 3);
    try testing.expect(image.IHDR.height == 3);
    try testing.expect(image.pixel_buf.len == 3);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 1);
    try testing.expect(image.PLTE.?.sections.len == 6);
}

test "decode 4 x 4 image" {
    const file_path = "samples/odd_sizes/s04n3p01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 4);
    try testing.expect(image.IHDR.height == 4);
    try testing.expect(image.pixel_buf.len == 4);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 1);
    try testing.expect(image.PLTE.?.sections.len == 6);
}

test "decode 5 x 5 image" {
    const file_path = "samples/odd_sizes/s05n3p02.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 5);
    try testing.expect(image.IHDR.height == 5);
    try testing.expect(image.pixel_buf.len == 10);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 2);
    try testing.expect(image.PLTE.?.sections.len == 9);
}

test "decode 6 x 6 image" {
    const file_path = "samples/odd_sizes/s06n3p02.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 6);
    try testing.expect(image.IHDR.height == 6);
    try testing.expect(image.pixel_buf.len == 12);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 2);
    try testing.expect(image.PLTE.?.sections.len == 9);
}

test "decode 7 x 7 image" {
    const file_path = "samples/odd_sizes/s07n3p02.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 7);
    try testing.expect(image.IHDR.height == 7);
    try testing.expect(image.pixel_buf.len == 14);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 2);
    try testing.expect(image.PLTE.?.sections.len == 12);
}

test "decode 8 x 8 image" {
    const file_path = "samples/odd_sizes/s08n3p02.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 8);
    try testing.expect(image.IHDR.height == 8);
    try testing.expect(image.pixel_buf.len == 16);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 2);
    try testing.expect(image.PLTE.?.sections.len == 12);
}

test "decode 9 x 9 image" {
    const file_path = "samples/odd_sizes/s09n3p02.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 9);
    try testing.expect(image.IHDR.height == 9);
    try testing.expect(image.pixel_buf.len == 27);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 2);
    try testing.expect(image.PLTE.?.sections.len == 12);
}

test "decode 33 x 33 image" {
    const file_path = "samples/odd_sizes/s33n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 33);
    try testing.expect(image.IHDR.height == 33);
    try testing.expect(image.pixel_buf.len == 561);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 34 x 34 image" {
    const file_path = "samples/odd_sizes/s34n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 34);
    try testing.expect(image.IHDR.height == 34);
    try testing.expect(image.pixel_buf.len == 578);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 35 x 35 image" {
    const file_path = "samples/odd_sizes/s35n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 35);
    try testing.expect(image.IHDR.height == 35);
    try testing.expect(image.pixel_buf.len == 630);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 36 x 36 image" {
    const file_path = "samples/odd_sizes/s36n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 36);
    try testing.expect(image.IHDR.height == 36);
    try testing.expect(image.pixel_buf.len == 648);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 37 x 37 image" {
    const file_path = "samples/odd_sizes/s37n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 37);
    try testing.expect(image.IHDR.height == 37);
    try testing.expect(image.pixel_buf.len == 703);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 38 x 38 image" {
    const file_path = "samples/odd_sizes/s38n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 38);
    try testing.expect(image.IHDR.height == 38);
    try testing.expect(image.pixel_buf.len == 722);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 39 x 39 image" {
    const file_path = "samples/odd_sizes/s39n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 39);
    try testing.expect(image.IHDR.height == 39);
    try testing.expect(image.pixel_buf.len == 780);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}

test "decode 40 x 40 image" {
    const file_path = "samples/odd_sizes/s40n3p04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.width == 40);
    try testing.expect(image.IHDR.height == 40);
    try testing.expect(image.pixel_buf.len == 800);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.IHDR.bit_depth == 4);
    try testing.expect(image.PLTE.?.sections.len == 39);
}
