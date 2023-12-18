pub const PNGReadError = error{
    NotPNG,
    CorruptedCRC,
    PLTENotDivisibleByThree,
    hISTNotValidU16Slice,
    InvalidsPLT,
    InvalidsPLTSampleDeth,
    InvalidcICPMatrixCoefficient,
    InvalidCompressionMethod,
    InvalidAnimationSequenceNumber,
    ZlibInflateInitError,
    ZlibMemoryError,
};
