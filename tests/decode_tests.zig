const std = @import("std");
const decoder = @import("decoder");

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
    defer allocator.deinit();
    defer idatAllocator.deinit();
    defer uncompressedAllocator.deinit();

    const arena = allocator.allocator();
    const file_path = "samples/image2.png";
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var file_size = try file.getEndPos();
    //  var f_file_size = @as(f32, @floatFromInt(file_size));
    var buffer = arena.alloc(u8, file_size) catch |err| {
        std.debug.print("error 1: {any}\n", .{err});
        return err;
    };
    defer arena.free(buffer);
    const pngDecode = decoder.pngDecoder();
    _ = try file.read(buffer);
    var PNG = try pngDecode.init(idatAllocator.allocator(), uncompressedAllocator.allocator(), buffer, file_size);
    PNG.readChunks() catch |err| {
        std.debug.print("error: {any}\n", .{err});
    };
}
