pub const png_decoder = @import("src/decode/decoder.zig");
pub const png_models = @import("src/decode/models.zig");
pub const png_unfilter = @import("src/decode/unfilter.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
    inline for (.{
        @import("tests/decoding_tests/color_filter.zig"),
        @import("tests/decoding_tests/greyscale_filter.zig"),
    }) |source_file| std.testing.refAllDeclsRecursive(source_file);
}
