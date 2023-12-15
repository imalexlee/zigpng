const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

const keywords = [_][]const u8{
    "Title",
};

test "decode greyscale image with regular textual data" {
    const file_path = "samples/text/ct1n0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .tEXt = true,
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

    try testing.expect(std.mem.eql(u8, image.tEXt_list.?.items[0].keyword, "Title"));
    try testing.expect(std.mem.eql(u8, image.tEXt_list.?.items[0].text, "PngSuite"));
}

//test "decode greyscale image with compressed textual data" {
//    const file_path = "samples/text/ctzn0g04.png";
//    const pngDecoder = png_decoder.pngDecoder();
//    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
//        .zTXt = true,
//    });
//    defer image.deinit();
//
//    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
//    try image.readInfo();
//    try image.readImageData();
//
//    try testing.expect(image.IHDR.width == 32);
//    try testing.expect(image.IHDR.height == 32);
//    try testing.expect(image.sample_size == 1);
//    try testing.expect(image.pixel_buf.len == 512);
//    try testing.expect(image.IHDR.bit_depth == 4);
//
//    for (image.zTXt_list.?.items) |chunk| {
//        std.debug.print("keyword: {s}\n", .{chunk.keyword});
//        std.debug.print("text: {s}\n", .{chunk.uncompressed_text});
//    }
//}
//
test "decode greyscale image with international english textual data" {
    const file_path = "samples/text/cten0g04.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .iTXt = true,
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

    for (image.iTXt_list.?.items) |chunk| {
        std.debug.print("compression_flag: {}\n", .{chunk.compression_flag});
        std.debug.print("language tag: {s}\n", .{chunk.language_tag});

        std.debug.print("keyword: {s}\n", .{chunk.keyword});
        std.debug.print("text: {s}\n\n", .{chunk.uncompressed_text});
    }
}
