#import "MEDefs.h"

const double MEFloatTolerance = 0.01;
const double MEDoubleTolerance = 0.0001;

NSArray<NSNumber *> *MEAllValueTypes(void) {
    static NSArray<NSNumber *> *types = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = @[
            @(MEValueTypeInt8), @(MEValueTypeUInt8),
            @(MEValueTypeInt16), @(MEValueTypeUInt16),
            @(MEValueTypeInt32), @(MEValueTypeUInt32),
            @(MEValueTypeInt64), @(MEValueTypeUInt64),
            @(MEValueTypeFloat), @(MEValueTypeDouble),
            @(MEValueTypeString),
        ];
    });
    return types;
}

NSString *MEValueTypeName(MEValueType type) {
    switch (type) {
        case MEValueTypeInt8: return @"Int8";
        case MEValueTypeUInt8: return @"UInt8";
        case MEValueTypeInt16: return @"Int16";
        case MEValueTypeUInt16: return @"UInt16";
        case MEValueTypeInt32: return @"Int32";
        case MEValueTypeUInt32: return @"UInt32";
        case MEValueTypeInt64: return @"Int64";
        case MEValueTypeUInt64: return @"UInt64";
        case MEValueTypeFloat: return @"Float";
        case MEValueTypeDouble: return @"Double";
        case MEValueTypeString: return @"String";
    }
    return @"?";
}

NSUInteger MEValueTypeFixedSize(MEValueType type) {
    switch (type) {
        case MEValueTypeInt8:
        case MEValueTypeUInt8: return 1;
        case MEValueTypeInt16:
        case MEValueTypeUInt16: return 2;
        case MEValueTypeInt32:
        case MEValueTypeUInt32:
        case MEValueTypeFloat: return 4;
        case MEValueTypeInt64:
        case MEValueTypeUInt64:
        case MEValueTypeDouble: return 8;
        case MEValueTypeString: return 0;
    }
    return 0;
}
