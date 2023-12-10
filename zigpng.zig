pub const png_decoder = @import("src/decode/decoder.zig");
pub const png_chunks = @import("src/decode/chunks.zig");
pub const png_unfilter = @import("src/decode/unfilter.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
    inline for (.{
        @import("tests/decoding_tests/color_filter.zig"),
        @import("tests/decoding_tests/greyscale_filter.zig"),
        @import("tests/decoding_tests/color_idat_variations.zig"),
        @import("tests/decoding_tests/greyscale_idat_variations.zig"),
        // @import("tests/decoding_tests/odd_sizes.zig"),
        @import("tests/decoding_tests/helpers.zig"),
    }) |source_file| std.testing.refAllDeclsRecursive(source_file);
}
