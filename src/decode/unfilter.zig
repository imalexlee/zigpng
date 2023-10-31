const std = @import("std");

/// Unfilters a filter type 1 scanline
pub fn unFilterSub(idat_buffer: []u8, line_num: usize, line_width: u32, bytes_per_pix: u8) void {
    // std.debug.print("sub\n", .{});
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
    // std.debug.print("up\n", .{});
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
    // std.debug.print("average\n", .{});
    // skip filter byte
    var i: u32 = 1;
    while (i < line_width) {
        var start_idx = line_num * line_width + i;
        var a_line_pos = i -| bytes_per_pix;
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
pub fn unFilterPaeth(idat_buffer: []u8, line_num: usize, line_width: u32, bytes_per_pix: u8) void {
    // std.debug.print("paeth\n", .{});
    var i: u32 = 1;
    while (i < line_width) {
        var start_idx = line_num * line_width + i;
        var a_line_pos = i -| bytes_per_pix;
        var c_line_pos = i -| bytes_per_pix;
        var a_start = line_num * line_width + a_line_pos;
        var b_start = (line_num -| 1) * line_width + i;
        var c_start = (line_num -| 1) * line_width + c_line_pos;

        for (0..bytes_per_pix) |paeth_idx| {
            var a = if (a_line_pos == 0) 0 else idat_buffer[a_start + paeth_idx];
            var b = if (line_num == 0) 0 else idat_buffer[b_start + paeth_idx];
            var c = if (line_num == 0 or c_line_pos == 0) 0 else idat_buffer[c_start + paeth_idx];
            idat_buffer[start_idx + paeth_idx] +%= paethPredictor(a, b, c);
        }
        i += bytes_per_pix;
    }
}

fn paethPredictor(a: u8, b: u8, c: u8) u8 {
    var ia = @as(i32, a);
    var ib = @as(i32, b);
    var ic = @as(i32, c);
    var p = ia + ib - ic;
    var pa = @abs(p - ia);
    var pb = @abs(p - ib);
    var pc = @abs(p - ic);

    if (pa <= pb and pa <= pc) {
        return a;
    } else if (pb <= pc) {
        return b;
    }
    return c;
}
