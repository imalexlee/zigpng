const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");
const PNGReadError = @import("../src/decode/errors.zig").PNGReadError;

const testing = std.testing;

test "attempting to read image information when no image was loaded in" {
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    var result = image.readInfo();

    try testing.expectError(
        PNGReadError.NoImageProvided,
        result,
    );
}

test "attempting to read image data when no image was loaded in" {
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    var result = image.readImageData();

    try testing.expectError(
        PNGReadError.NoImageProvided,
        result,
    );
}

test "call readImageData before readInfo" {
    const file_path = "samples/filtering/color/f00n2c08.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});

    var result = image.readImageData();
    try image.readInfo();

    try testing.expectError(
        PNGReadError.ImageInformationNotRead,
        result,
    );
}

test "check that only calling reset frees all memory and no seg faults" {
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .pHYS = true,
        .bKGD = true,
        .sRGB = true,
        .sBIT = true,
        .sPLT = true,
        .gAMA = true,
        .cHRM = true,
        .hIST = true,
        .tIME = true,
        .tEXt = true,
        .zTXt = true,
        .iTXt = true,
        .eXIf = true,
        .iCCP = true,
        .cICP = true,
        .mDCv = true,
        .cLLi = true,
        .animation = true,
    });
    image.reset();
}

test "check that only calling deinit frees all memory and no seg faults" {
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .pHYS = true,
        .bKGD = true,
        .sRGB = true,
        .sBIT = true,
        .sPLT = true,
        .gAMA = true,
        .cHRM = true,
        .hIST = true,
        .tIME = true,
        .tEXt = true,
        .zTXt = true,
        .iTXt = true,
        .eXIf = true,
        .iCCP = true,
        .cICP = true,
        .mDCv = true,
        .cLLi = true,
        .animation = true,
    });
    image.deinit();
}
