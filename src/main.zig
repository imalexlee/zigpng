const std = @import("std");
const zlib = @cImport(@cInclude("zlib.h"));
const pngDecoder = @import("./decode/decoder.zig");

// zig build-exe src/main.zig -O ReleaseFast -fstrip -lc -lz
// zig build -Doptimize=ReleaseFast
pub fn main() !void {
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

    const startTime = std.time.microTimestamp();
    var allocator = std.heap.ArenaAllocator.init(gpa.backing_allocator);
    var idatAllocator = std.heap.ArenaAllocator.init(idatGpa.backing_allocator);
    var uncompressedAllocator = std.heap.ArenaAllocator.init(uncompressedGpa.backing_allocator);
    const arena = allocator.allocator();
    const file_path = "samples/image2.png";
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var file_size = try file.getEndPos();
    var f_file_size = @as(f32, @floatFromInt(file_size));
    var buffer = try arena.alloc(u8, file_size);
    defer arena.free(buffer);

    const pngDecode = pngDecoder.pngDecoder();
    _ = try file.read(buffer);
    var PNG = try pngDecode.init(idatAllocator.allocator(), uncompressedAllocator.allocator(), buffer, file_size);
    _ = try PNG.readChunks();
    PNG.print();

    const timeElapsed = std.time.microTimestamp() - startTime;
    const f_timeElapsed = @as(f32, @floatFromInt(timeElapsed));
    const mb_processed: f32 = f_file_size / 1_000_000.0;
    const seconds_elapsed: f32 = f_timeElapsed / 1_000_000.0;
    const mb_per_sec: f32 = mb_processed / seconds_elapsed;

    std.debug.print("{any} bytes completed in {d} μs\n", .{ file_size, timeElapsed });
    std.debug.print("{d:.3} mb/s\n", .{mb_per_sec});
}
