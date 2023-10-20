const std = @import("std");
const zlib = @cImport(@cInclude("zlib.h"));
const pngDecoder = @import("./png/pngDecoder.zig");
// fast !!!
// zig build-exe src/main.zig -O ReleaseFast -fstrip -lc -lz
pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
    }){};
    const idatGpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
    }){};
    const startTime = std.time.microTimestamp();
    var allocator = std.heap.ArenaAllocator.init(gpa.backing_allocator);
    var idatAllocator = std.heap.ArenaAllocator.init(idatGpa.backing_allocator);
    const arena = allocator.allocator();
    const file_path = "samples/vibrant.png";
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var file_size = try file.getEndPos();
    var buffer = try arena.alloc(u8, file_size);
    defer arena.free(buffer);

    const pngDecode = pngDecoder.pngDecoder();
    _ = try file.read(buffer);
    var PNG = pngDecode.init(idatAllocator.allocator(), buffer, file_size);
    _ = try PNG.readChunks();
    PNG.print();

    const timeElapsed = std.time.microTimestamp() - startTime;
    std.debug.print("completed in {d} μs\n", .{timeElapsed});
}
