const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");
const helpers = @import("helpers.zig");

const testing = std.testing;

test "decode color animated PNG (APNG)" {
    const file_path = "samples/animation/clock.png";
    const pngDecoder = png_decoder.pngDecoder();
    var image = try pngDecoder.init(helpers.zigpng_test_allocator, helpers.zigpng_test_allocator, .{
        .animation = true,
    });
    defer image.deinit();

    try image.loadFileFromPath(helpers.zigpng_test_allocator, file_path, .{});
    try image.readInfo();
    try image.readImageData();
    try testing.expect(image.IHDR.width == 150);
    try testing.expect(image.IHDR.height == 150);
    try testing.expect(image.sample_size == 1);

    try testing.expect(image.acTL.?.num_frames == image.fcTL_list.?.items.len);
    try testing.expect(image.acTL.?.num_plays == 0);

    var total_pixels: u32 = 0;
    for (image.fcTL_list.?.items) |value| {
        total_pixels += value.width * value.height * image.sample_size;
    }

    try testing.expect(image.pixel_buf.len == total_pixels);
}
