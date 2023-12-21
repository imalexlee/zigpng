const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

const keywords = [_][]const u8{
    "Title",
    "Author",
    "Copyright",
    "Description",
    "Software",
    "Disclaimer",
};

test "decode greyscale image with regular textual data" {
    const file_path = "samples/text/ct1n0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .tEXt = true,
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
    for (image.tEXt_list.?.items, 0..) |chunk, i| {
        try std.testing.expectEqualStrings(chunk.keyword, keywords[i]);
    }
}

test "decode greyscale image with compressed textual data" {
    const file_path = "samples/text/ctzn0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .zTXt = true,
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
}

test "decode greyscale image with international english textual data" {
    const file_path = "samples/text/cten0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .iTXt = true,
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

    for (image.iTXt_list.?.items, 0..) |chunk, i| {
        try std.testing.expectEqualStrings(chunk.keyword, keywords[i]);
        try std.testing.expectEqualStrings(chunk.language_tag, "en");
    }
}

test "decode greyscale image with international finnish textual data" {
    const file_path = "samples/text/ctfn0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .iTXt = true,
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

    for (image.iTXt_list.?.items, 0..) |chunk, i| {
        try std.testing.expectEqualStrings(chunk.keyword, keywords[i]);
        try std.testing.expectEqualStrings(chunk.language_tag, "fi");
    }
}
