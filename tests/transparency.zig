const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode greyscale transparent with black background" {
    const file_path = "samples/transparent/greyscale/tbbn0g04.png";
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
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 512);
    try testing.expect(image.IHDR.?.bit_depth == 4);
    try testing.expect(image.bKGD.?.greyscale.? == 0);
    try testing.expect(image.tRNS.?.grey_sample.? == 15);
    try testing.expect(image.tRNS.?.alphas == null);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}

test "decode color transparent with blue background" {
    const file_path = "samples/transparent/color/tbbn2c16.png";
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
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 6144);
    try testing.expect(image.IHDR.?.bit_depth == 16);
    try testing.expect(image.bKGD.?.red.? == 0);
    try testing.expect(image.bKGD.?.green.? == 0);
    try testing.expect(image.bKGD.?.blue.? == 65535);
    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas == null);
    try testing.expect(image.tRNS.?.red_sample != null);
    try testing.expect(image.tRNS.?.green_sample != null);
    try testing.expect(image.tRNS.?.blue_sample != null);
}

test "decode paletted transparent with black background" {
    const file_path = "samples/transparent/color/tbbn3p08.png";
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
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);
    try testing.expect(image.IHDR.?.bit_depth == 8);
    try testing.expect(image.bKGD.?.red == null);
    try testing.expect(image.bKGD.?.green == null);
    try testing.expect(image.bKGD.?.blue == null);
    try testing.expect(image.bKGD.?.palette_index != null);

    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas != null);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}

test "decode color transparent with green background" {
    const file_path = "samples/transparent/color/tbgn2c16.png";
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
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 6144);
    try testing.expect(image.IHDR.?.bit_depth == 16);
    try testing.expect(image.bKGD.?.red.? == 0);
    try testing.expect(image.bKGD.?.green.? == 65535);
    try testing.expect(image.bKGD.?.blue.? == 0);
    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas == null);
    try testing.expect(image.tRNS.?.red_sample != null);
    try testing.expect(image.tRNS.?.green_sample != null);
    try testing.expect(image.tRNS.?.blue_sample != null);
}

test "decode paletted transparent with light grey background" {
    const file_path = "samples/transparent/color/tbgn3p08.png";
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
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);
    try testing.expect(image.IHDR.?.bit_depth == 8);
    try testing.expect(image.bKGD.?.red == null);
    try testing.expect(image.bKGD.?.green == null);
    try testing.expect(image.bKGD.?.blue == null);
    try testing.expect(image.bKGD.?.palette_index != null);

    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas != null);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}

test "decode color transparent with red background" {
    const file_path = "samples/transparent/color/tbrn2c08.png";
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
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.pixel_buf.len == 3072);
    try testing.expect(image.IHDR.?.bit_depth == 8);
    try testing.expect(image.bKGD.?.red.? == 255);
    try testing.expect(image.bKGD.?.green.? == 0);
    try testing.expect(image.bKGD.?.blue.? == 0);
    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas == null);
    try testing.expect(image.tRNS.?.red_sample != null);
    try testing.expect(image.tRNS.?.green_sample != null);
    try testing.expect(image.tRNS.?.blue_sample != null);
}

test "decode greyscale transparent with white background" {
    const file_path = "samples/transparent/greyscale/tbwn0g16.png";
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
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 2048);
    try testing.expect(image.IHDR.?.bit_depth == 16);
    try testing.expect(image.bKGD.?.greyscale.? == 65535);
    try testing.expect(image.tRNS.?.grey_sample != null);
    try testing.expect(image.tRNS.?.alphas == null);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}

test "decode paletted transparent with white background" {
    const file_path = "samples/transparent/color/tbwn3p08.png";
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
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);
    try testing.expect(image.IHDR.?.bit_depth == 8);
    try testing.expect(image.bKGD.?.red == null);
    try testing.expect(image.bKGD.?.green == null);
    try testing.expect(image.bKGD.?.blue == null);

    var white_idx: u32 = undefined;
    var i: u32 = 0;
    while (i < image.PLTE.?.sections.len) {
        const red: u8 = image.PLTE.?.sections[i];
        const green: u8 = image.PLTE.?.sections[i + 1];
        const blue: u8 = image.PLTE.?.sections[i + 2];

        if (red == 255 and green == 255 and blue == 255) {
            white_idx = i / 3;
        }
        i += 3;
    }
    try testing.expect(image.bKGD.?.palette_index.? == white_idx);

    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas != null);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}

test "decode paletted transparent with yellow background" {
    const file_path = "samples/transparent/color/tbyn3p08.png";
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
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 1024);
    try testing.expect(image.IHDR.?.bit_depth == 8);
    try testing.expect(image.bKGD.?.red == null);
    try testing.expect(image.bKGD.?.green == null);
    try testing.expect(image.bKGD.?.blue == null);

    var yellow_idx: u32 = undefined;
    var i: u32 = 0;
    while (i < image.PLTE.?.sections.len) {
        const red: u8 = image.PLTE.?.sections[i];
        const green: u8 = image.PLTE.?.sections[i + 1];
        const blue: u8 = image.PLTE.?.sections[i + 2];

        if (red == 255 and green == 255 and blue == 0) {
            yellow_idx = i / 3;
        }
        i += 3;
    }
    try testing.expect(image.bKGD.?.palette_index.? == yellow_idx);

    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas != null);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}

test "decode paletted transparent with 3 different transparency indices" {
    const file_path = "samples/transparent/color/tm3n3p02.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{});
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 32);
    try testing.expect(image.IHDR.?.height == 32);
    try testing.expect(image.sample_size == 1);
    try testing.expect(image.pixel_buf.len == 256);
    try testing.expect(image.IHDR.?.bit_depth == 2);

    try testing.expect(image.tRNS.?.grey_sample == null);
    try testing.expect(image.tRNS.?.alphas.?.len == 3);
    try testing.expect(image.tRNS.?.red_sample == null);
    try testing.expect(image.tRNS.?.green_sample == null);
    try testing.expect(image.tRNS.?.blue_sample == null);
}
