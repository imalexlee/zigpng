pub const png_decoder = @import("src/decode/decoder.zig");
pub const png_chunks = @import("src/decode/chunks.zig");
pub const png_unfilter = @import("src/decode/unfilter.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
    inline for (.{
        @import("tests/filters.zig"),
        @import("tests/idat_variations.zig"),
        @import("tests/odd_sizes.zig"),
        @import("tests/backgrounds.zig"),
        @import("tests/transparency.zig"),
        @import("tests/gama.zig"),
        @import("tests/helpers.zig"),
    }) |source_file| std.testing.refAllDeclsRecursive(source_file);
}
