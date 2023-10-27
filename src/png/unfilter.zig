const std = @import("std");

/// Unfilters a filter type 1 scanline
pub fn unFilterSub(idat_buffer: []u8, line_num: usize, line_width: u32, bytes_per_pix: u8) void {
    // start at second pixel and skip filter byte
    var i: u32 = bytes_per_pix + 1;
    while (i < line_width) {
        var start_idx = line_num * line_width + i;
        for (0..bytes_per_pix) |addition_idx| {
            idat_buffer[start_idx + addition_idx] +%=
                idat_buffer[start_idx + addition_idx - bytes_per_pix];
        }
        i += bytes_per_pix;
    }
}
/// Unfilters a filter type 2 scanline
pub fn unFilterUp(idat_buffer: []u8, line_num: usize, line_width: u32, bytes_per_pix: u8) void {
    if (line_num == 0) return;
    // skip filter byte
    var i: u32 = 1;
    while (i < line_width) {
        var start_idx = line_num * line_width + i;
        var prev_line_start_idx = (line_num - 1) * line_width + i;
        for (0..bytes_per_pix) |addition_idx| {
            idat_buffer[start_idx + addition_idx] +%=
                idat_buffer[prev_line_start_idx + addition_idx];
        }
        i += bytes_per_pix;
    }
}

/// Unfilters a filter type 3 scanline
pub fn unFilterAverage(idat_buffer: []u8, line_num: usize, line_width: u32, bytes_per_pix: u8) void {
    // skip filter byte
    var i: u32 = 1;
    while (i < line_width) {
        var a_line_pos = i -| bytes_per_pix;
        var start_idx = line_num * line_width + i;
        var a_start = line_num * line_width + a_line_pos;
        var b_start = (line_num -| 1) * line_width + i;
        for (0..bytes_per_pix) |average_idx| {
            var a = @as(f32, @floatFromInt(if (a_line_pos == 0) 0 else idat_buffer[a_start + average_idx]));
            var b = @as(f32, @floatFromInt(if (line_num == 0) 0 else idat_buffer[b_start + average_idx]));
            idat_buffer[start_idx + average_idx] +%= @intFromFloat(@floor((a + b) / 2));
        }
        i += bytes_per_pix;
    }
}

/// Unfilters a filter type 4 scanline
pub fn unFilterPaeth() void {
    std.debug.print("unfiltering filter 4\n", .{});
}
