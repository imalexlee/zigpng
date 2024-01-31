const std = @import("std");

/// Unfilters a filter type 1 scanline
///
/// Takes a full scanline INCLUDING the filter byte
pub fn unFilterSub(idat_buffer: []u8, line_num: usize, line_width: u32, sample_size: u8) void {
    var i: u32 = sample_size + 1;
    while (i < line_width) {
        const start_idx = line_num * line_width + i;
        for (0..sample_size) |addition_idx| {
            idat_buffer[start_idx + addition_idx] +%=
                idat_buffer[start_idx + addition_idx - sample_size];
        }
        i += sample_size;
    }
}

/// Unfilters a filter type 2 scanline
///
/// Takes a full scanline INCLUDING the filter byte
pub fn unFilterUp(idat_buffer: []u8, line_num: usize, line_width: u32, sample_size: u8) void {
    if (line_num == 0) return;
    var i: u32 = 1;
    while (i < line_width) {
        const start_idx = line_num * line_width + i;
        const prev_line_start_idx = (line_num - 1) * line_width + i;
        for (0..sample_size) |addition_idx| {
            idat_buffer[start_idx + addition_idx] +%=
                idat_buffer[prev_line_start_idx + addition_idx];
        }
        i += sample_size;
    }
}

/// Unfilters a filter type 3 scanline
///
/// Takes a full scanline INCLUDING the filter byte
pub fn unFilterAverage(idat_buffer: []u8, line_num: usize, line_width: u32, sample_size: u8) void {
    var i: u32 = 1;
    while (i < line_width) {
        const start_idx = line_num * line_width + i;
        const a_line_pos = i -| sample_size;
        const a_start = line_num * line_width + a_line_pos;
        const b_start = (line_num -| 1) * line_width + i;
        for (0..sample_size) |average_idx| {
            const a = @as(f32, @floatFromInt(if (a_line_pos == 0) 0 else idat_buffer[a_start + average_idx]));
            const b = @as(f32, @floatFromInt(if (line_num == 0) 0 else idat_buffer[b_start + average_idx]));
            idat_buffer[start_idx + average_idx] +%= @intFromFloat(@floor((a + b) / 2));
        }
        i += sample_size;
    }
}

/// Unfilters a filter type 4 scanline
///
/// Takes a full scanline INCLUDING the filter byte
pub fn unFilterPaeth(idat_buffer: []u8, line_num: usize, line_width: u32, sample_size: u8) void {
    var i: u32 = 1;
    while (i < line_width) {
        const start_idx = line_num * line_width + i;
        const a_line_pos = i -| sample_size;
        const c_line_pos = i -| sample_size;
        const a_start = line_num * line_width + a_line_pos;
        const b_start = (line_num -| 1) * line_width + i;
        const c_start = (line_num -| 1) * line_width + c_line_pos;

        for (0..sample_size) |paeth_idx| {
            const a = if (a_line_pos == 0) 0 else idat_buffer[a_start + paeth_idx];
            const b = if (line_num == 0) 0 else idat_buffer[b_start + paeth_idx];
            const c = if (line_num == 0 or c_line_pos == 0) 0 else idat_buffer[c_start + paeth_idx];
            idat_buffer[start_idx + paeth_idx] +%= paethPredictor(a, b, c);
        }
        i += sample_size;
    }
}

fn paethPredictor(a: u8, b: u8, c: u8) u8 {
    const ia = @as(i32, a);
    const ib = @as(i32, b);
    const ic = @as(i32, c);
    const p = ia + ib - ic;
    const pa = @abs(p - ia);
    const pb = @abs(p - ib);
    const pc = @abs(p - ic);

    if (pa <= pb and pa <= pc) {
        return a;
    } else if (pb <= pc) {
        return b;
    }
    return c;
}
