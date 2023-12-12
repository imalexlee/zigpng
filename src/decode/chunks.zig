// http://www.libpng.org/pub/png/spec/iso/index-object.html

// CRITICAL CHUNKS
pub const IHDR = struct {
    width: u32,
    height: u32,
    bit_depth: u8,
    color_type: u8,
    compression_method: u8,
    filter_method: u8,
    interlace_method: u8,
};

pub const PLTE = struct {
    sections: []u8,
};

const plte_section = struct {
    red: u8,
    green: u8,
    blue: u8,
};

// ANCILLARY CHUNKS

// TRANSPARENCY
pub const tRNS = struct {
    grey_sample: u16,
    red_sample: u16,
    green_sample: u16,
    blue_sample: u16,
    alphas: []u8,
};

// COLOR SPACE
pub const cHRM = struct {
    white_point_x: u32,
    white_point_y: u32,
    red_x: u32,
    red_y: u32,
    green_x: u32,
    green_y: u32,
    blue_x: u32,
    blue_y: u32,
};

pub const gAMA = struct {
    image_gama: u32,
};

pub const iCCP = struct {
    profile_name: []u8,
    null_seperator: u8,
    compression_method: u8,
    compressed_profile: []u8,
};

/// t0:type 0. t23:type 2 or 3. t4:type 4. t6:type 6.
pub const sBIT = struct {
    sig_grey_bits_t0: u8,
    sig_red_bits_t23: u8,
    sig_green_bits_t23: u8,
    sig_blue_bits_t23: u8,
    sig_grey_bits_t4: u8,
    sig_alpha_bits_t4: u8,
    sig_red_bits_t6: u8,
    sig_green_bits_t6: u8,
    sig_blue_bits_t6: u8,
    sig_alpha_bits_t6: u8,
};

pub const sRGB = struct {
    rendering_intent: u8,
};

pub const cICP = struct {
    color_primaries: u8,
    transfer_function: u8,
    matrix_coefficients: u8,
    video_frf: u8,
};

pub const mDCv = struct {
    mastering_dcp: [12]u8,
    mastering_dwpc: u32,
    mastering_dmaxl: u32,
    mastering_dminl: u32,
};

pub const cLLi = struct {
    max_cll: u32,
    max_fall: u32,
};

// TEXTUAL INFORMATION

pub const tEXt = struct {
    keyword: []u8,
    null_seperator: u8,
    text: []u8,
};

pub const zTXt = struct {
    keyword: []u8,
    null_seperator: u8,
    compression_method: u8,
    compressed_text: []u8,
};

pub const iTXt = struct {
    keyword: []u8,
    null_seperator1: u8,
    compression_flag: u8,
    compression_method: u8,
    language_tag: []u8,
    null_seperator2: u8,
    translated_keyword: []u8,
    null_seperator3: u8,
    text: []u8,
};

// MISCELLANEOUS INFORMATION

pub const bKGD = struct {
    greyscale: u16,
    red: u16,
    green: u16,
    blue: u16,
    palette_index: u8,
};

pub const hIST = struct {
    frequencies: []u16,
};

pub const pHYs = struct {
    ppu_x: u32,
    ppu_y: u32,
    unit_specifier: u8,
};

pub const sPLT = struct {
    palette_name: []u8,
    null_seperator: u8,
    sample_depth: u8,
    palette: []splt_palette,
};

const splt_palette = struct {
    red: u16,
    green: u16,
    blue: u16,
    alpha: u16,
    frequency: u16,
};

pub const eXIf = struct {
    exif_data: []u8,
};

// TIME

pub const tIME = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
};

// ANIMATION INFORMATION

pub const acTL = struct {
    num_frames: u32,
    num_plays: u32,
};

pub const fcTL = struct {
    sequence_number: u32,
    width: u32,
    height: u32,
    x_offset: u32,
    y_offset: u32,
    delay_num: u16,
    delay_den: u16,
    dispose_op: u8,
    blend_op: u8,
};

pub const fdAT = struct {
    sequence_number: u32,
    frame_data: []u8,
};
