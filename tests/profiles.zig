const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color image with iCCP" {
    const file_path = "samples/profile/macbeth-v2-CIE-Lstar.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = pngDecoder.init(helpers.zigpng_test_allocator, .{
        .iCCP = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(file_path, .{});
    try image.readInfo();
    try image.readImageData();

    try testing.expect(image.IHDR.?.width == 670);
    try testing.expect(image.IHDR.?.height == 450);
    try testing.expect(image.sample_size == 3);
    try testing.expect(image.IHDR.?.bit_depth == 8);
    try testing.expect(image.pixel_buf.len == 904_500);

    try testing.expect(image.iCCP.?.compression_method == 0);
    try testing.expectEqualStrings(image.iCCP.?.profile_name, "LittleCMS ICC profile");
}
