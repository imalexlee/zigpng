const std = @import("std");

pub fn unFilterSub(idat_buffer: []u8, line_num: usize, line_width: u32, bytes_per_pix: u8) void {
    // second pixel is 1 + bpp
    var i: u32 = bytes_per_pix + 1;
    std.debug.print("line_width in unFilterSub: {any}\n", .{line_width});
    for (0..line_width) |idx| {
        std.debug.print("og val at idx {d}: {any}\n", .{ idx, idat_buffer[idx] });
    }
    while (i < line_width) {
        // std.debug.print("i: {any}\n", .{i});
        for (0..bytes_per_pix) |addition_idx| {
            var start_byte = line_num * line_width + i;
            // std.debug.print("before: {d}\n", .{idat_buffer[start_byte + addition_idx]});
            idat_buffer[start_byte + addition_idx] +%=
                idat_buffer[start_byte + addition_idx - bytes_per_pix];
            // std.debug.print("after: {d}\n", .{idat_buffer[start_byte + addition_idx]});
        }
        i += bytes_per_pix;
    }
    for (0..line_width) |idx| {
        std.debug.print("filtered val at idx {d}: {any}\n", .{ idx, idat_buffer[idx] });
    }

    std.debug.print("~~~~~~~~ NEW LINE ~~~~~~~~\n", .{});
    unreachable;
}
pub fn unFilterUp() void {
    std.debug.print("unfiltering filter 2\n", .{});
}
pub fn unFilterAverage() void {
    std.debug.print("unfiltering filter 3\n", .{});
}
pub fn unFilterPaeth() void {
    std.debug.print("unfiltering filter 4\n", .{});
}
