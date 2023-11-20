const std = @import("std");
const decoder = @import("../src/decode/decoder.zig");

//test "Checksum passes on valid images" {}

test "u32_at_offset gets correct inline result" {
    const buffer = [10]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var buffer_slice = &buffer;
    const offset = 2;

    var pull_r = decoder.pull_u32_at_offset(offset, buffer_slice);
    var orig_r: u32 =
        @as(u32, buffer_slice[offset]) << 24 |
        @as(u32, buffer_slice[offset + 1]) << 16 |
        @as(u32, buffer_slice[offset + 2]) << 8 |
        @as(u32, buffer_slice[offset + 3]);

    std.testing.expect(pull_r == orig_r);
}

test "decode an image" {
    const gpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
    }){};

    const idatGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .verbose_log = true,
    }){};

    const uncompressedGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .verbose_log = true,
    }){};

    // const startTime = std.time.microTimestamp();
    var allocator = std.heap.ArenaAllocator.init(gpa.backing_allocator);
    var idatAllocator = std.heap.ArenaAllocator.init(idatGpa.backing_allocator);
    var uncompressedAllocator = std.heap.ArenaAllocator.init(uncompressedGpa.backing_allocator);
    const arena = allocator.allocator();
    const file_path = "samples/image2.png";
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var file_size = try file.getEndPos();
    //  var f_file_size = @as(f32, @floatFromInt(file_size));
    var buffer = try arena.alloc(u8, file_size);
    defer arena.free(buffer);

    const pngDecode = decoder.pngDecoder();
    _ = try file.read(buffer);
    var PNG = try pngDecode.init(idatAllocator.allocator(), uncompressedAllocator.allocator(), buffer, file_size);
    _ = try PNG.readChunks();
}

fn init() !init_vals {
    const gpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
    }){};

    const idatGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .verbose_log = true,
    }){};

    const uncompressedGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .verbose_log = true,
    }){};

    // const startTime = std.time.microTimestamp();
    var allocator = std.heap.ArenaAllocator.init(gpa.backing_allocator);
    var idatAllocator = std.heap.ArenaAllocator.init(idatGpa.backing_allocator);
    var uncompressedAllocator = std.heap.ArenaAllocator.init(uncompressedGpa.backing_allocator);
    const arena = allocator.allocator();
    const file_path = "samples/image2.png";
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var file_size = try file.getEndPos();
    //  var f_file_size = @as(f32, @floatFromInt(file_size));
    var buffer = try arena.alloc(u8, file_size);
    defer arena.free(buffer);

    const pngDecode = decoder.pngDecoder();
    _ = try file.read(buffer);
    var PNG = try pngDecode.init(idatAllocator.allocator(), uncompressedAllocator.allocator(), buffer, file_size);
    //   _ = try PNG.readChunks();
    //   PNG.print();

    return init_vals{
        .image_buffer = buffer,
        .file_size = file_size,
        .decoder = PNG,
    };
    //  const timeElapsed = std.time.microTimestamp() - startTime;
    //  const f_timeElapsed = @as(f32, @floatFromInt(timeElapsed));
    //  const mb_processed: f32 = f_file_size / 1_000_000.0;
    //  const seconds_elapsed: f32 = f_timeElapsed / 1_000_000.0;
    //  const mb_per_sec: f32 = mb_processed / seconds_elapsed;

    //  std.debug.print("{any} bytes completed in {d} μs\n", .{ file_size, timeElapsed });
    //  std.debug.print("{d:.3} mb/s\n", .{mb_per_sec});
}

const init_vals = struct { image_buffer: []u8, file_size: u64, decoder: decoder.pngDecoder() };
