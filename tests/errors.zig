const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");
const PNGReadError = @import("../src/decode/errors.zig").PNGReadError;

const testing = std.testing;

test "Incorrect PNG signature" {
    const file_path = "samples/corrupted/xs2n0g01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidPNGSignature,
        result,
    );
}
test "Added Carriage Return byte in PNG signature" {
    const file_path = "samples/corrupted/xcrn0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidPNGSignature,
        result,
    );
}

test "Incorrect.IHDR.? checksum" {
    const file_path = "samples/corrupted/xhdn0g08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidChecksum,
        result,
    );
}

test "image with color type 1" {
    const file_path = "samples/corrupted/xc1n0g08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidColorType,
        result,
    );
}

test "image with color type 9" {
    const file_path = "samples/corrupted/xc9n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidColorType,
        result,
    );
}

test "image with bit depth of 1" {
    const file_path = "samples/corrupted/xd0n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidBitDepth,
        result,
    );
}

test "image with bit depth of 99" {
    const file_path = "samples/corrupted/xd9n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InvalidBitDepth,
        result,
    );
}

test "image with missing IDAT chunk" {
    const file_path = "samples/corrupted/xdtn0g01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.MissingIDAT,
        result,
    );
}

test "image with incorrect IDAT checksum" {
    const file_path = "samples/corrupted/xcsn0g01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    try image.readInfo();
    var result = image.readImageData();

    try testing.expectError(
        PNGReadError.InvalidChecksum,
        result,
    );
}

test "image with incorrect IDAT checksum with checks turned off" {
    const file_path = "samples/corrupted/xcsn0g01.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .checksum = false,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 128);
    try testing.expect(image.IHDR.?.bit_depth == 1);
}

test "Interlaced Image (Not supported)" {
    const file_path = "samples/corrupted/basi2c16.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.InterlacingNotSupported,
        result,
    );
}
