const std = @import("std");
const png_decoder = @import("../src/decode/decoder.zig");

//const decoder = png_decoder.pngDecoder();

test "decode an image" {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
    }){};
    var idatGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .verbose_log = true,
    }){};
    var uncompressedGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .verbose_log = true,
    }){};
    // const startTime = std.time.microTimestamp();
    const file_path = "samples/image2.png";
    const pngDecoder = png_decoder.pngDecoder();
    var decoder = try pngDecoder.init(idatGpa.allocator(), uncompressedGpa.allocator());
    defer decoder.deinit();

    try decoder.loadFileFromPath(gpa.allocator(), file_path, .{});
    decoder.readChunks() catch |err| {
        std.debug.print("error: {any}\n", .{err});
    };
}

test "ensure correct widths and heights of decoded images" {}
