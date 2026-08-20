#import "MemScanner.h"
#import "MEMachVM.h"

#pragma mark - MEMatch

@implementation MEMatch

- (instancetype)initWithAddress:(mach_vm_address_t)address type:(MEValueType)type {
    self = [super init];
    if (self) {
        _address = address;
        _type = type;
    }
    return self;
}

@end

#pragma mark - 値 <-> バイト列 変換

/// 入力文字列を型に応じた生バイト列(ネイティブバイトオーダー)に変換する。パース失敗時はnil。
static NSData *MEBytesFromValueString(NSString *valueString, MEValueType type) {
    const char *cstr = valueString.UTF8String;
    if (!cstr) return nil;

    switch (type) {
        case MEValueTypeString: {
            return [valueString dataUsingEncoding:NSUTF8StringEncoding];
        }
        case MEValueTypeFloat: {
            if (valueString.length == 0) return nil;
            float v = strtof(cstr, NULL);
            return [NSData dataWithBytes:&v length:sizeof(v)];
        }
        case MEValueTypeDouble: {
            if (valueString.length == 0) return nil;
            double v = strtod(cstr, NULL);
            return [NSData dataWithBytes:&v length:sizeof(v)];
        }
        case MEValueTypeInt8: {
            long long v = strtoll(cstr, NULL, 10);
            int8_t x = (int8_t)v;
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeUInt8: {
            unsigned long long v = strtoull(cstr, NULL, 10);
            uint8_t x = (uint8_t)v;
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeInt16: {
            long long v = strtoll(cstr, NULL, 10);
            int16_t x = (int16_t)v;
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeUInt16: {
            unsigned long long v = strtoull(cstr, NULL, 10);
            uint16_t x = (uint16_t)v;
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeInt32: {
            long long v = strtoll(cstr, NULL, 10);
            int32_t x = (int32_t)v;
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeUInt32: {
            unsigned long long v = strtoull(cstr, NULL, 10);
            uint32_t x = (uint32_t)v;
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeInt64: {
            int64_t x = strtoll(cstr, NULL, 10);
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
        case MEValueTypeUInt64: {
            uint64_t x = strtoull(cstr, NULL, 10);
            return [NSData dataWithBytes:&x length:sizeof(x)];
        }
    }
    return nil;
}

/// 生バイト列を表示用文字列に変換する。
static NSString *MEStringFromBytes(const void *bytes, NSUInteger length, MEValueType type) {
    switch (type) {
        case MEValueTypeString:
            return [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] ?: @"";
        case MEValueTypeFloat: {
            float v; memcpy(&v, bytes, sizeof(v));
            return [NSString stringWithFormat:@"%g", v];
        }
        case MEValueTypeDouble: {
            double v; memcpy(&v, bytes, sizeof(v));
            return [NSString stringWithFormat:@"%g", v];
        }
        case MEValueTypeInt8: { int8_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%d", v]; }
        case MEValueTypeUInt8: { uint8_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%u", v]; }
        case MEValueTypeInt16: { int16_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%d", v]; }
        case MEValueTypeUInt16: { uint16_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%u", v]; }
        case MEValueTypeInt32: { int32_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%d", v]; }
        case MEValueTypeUInt32: { uint32_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%u", v]; }
        case MEValueTypeInt64: { int64_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%lld", v]; }
        case MEValueTypeUInt64: { uint64_t v; memcpy(&v, bytes, sizeof(v)); return [NSString stringWithFormat:@"%llu", v]; }
    }
    return @"";
}

/// 2つのバイト列が型に応じた基準で「一致」とみなせるかどうか。float/doubleは許容誤差あり。
static BOOL MEBytesMatch(const void *a, const void *b, MEValueType type) {
    switch (type) {
        case MEValueTypeFloat: {
            float x, y; memcpy(&x, a, sizeof(x)); memcpy(&y, b, sizeof(y));
            return fabsf(x - y) <= MEFloatTolerance;
        }
        case MEValueTypeDouble: {
            double x, y; memcpy(&x, a, sizeof(x)); memcpy(&y, b, sizeof(y));
            return fabs(x - y) <= MEDoubleTolerance;
        }
        default:
            return memcmp(a, b, MEValueTypeFixedSize(type)) == 0;
    }
}

/// 固定長の数値型バイト列をdoubleへ変換する(範囲検索の比較用)。Stringには非対応。
/// Int64/UInt64は2^53を超える値でdoubleの丸め誤差が生じうるが、ゲーム内の
/// 一般的な数値(HP・所持金等)の範囲では実用上問題にならない。
static double MEDoubleFromBytes(const void *bytes, MEValueType type) {
    switch (type) {
        case MEValueTypeInt8: { int8_t v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeUInt8: { uint8_t v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeInt16: { int16_t v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeUInt16: { uint16_t v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeInt32: { int32_t v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeUInt32: { uint32_t v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeInt64: { int64_t v; memcpy(&v, bytes, sizeof(v)); return (double)v; }
        case MEValueTypeUInt64: { uint64_t v; memcpy(&v, bytes, sizeof(v)); return (double)v; }
        case MEValueTypeFloat: { float v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeDouble: { double v; memcpy(&v, bytes, sizeof(v)); return v; }
        case MEValueTypeString: return 0;
    }
    return 0;
}

#pragma mark - メモリ領域列挙

typedef struct {
    mach_vm_address_t address;
    mach_vm_size_t size;
} MERegion;

/// 対象タスクの書き込み可能な領域を列挙する。fullScan=NOの場合はmalloc系の匿名領域のみ。
static NSArray<NSValue *> *MEEnumerateRegions(task_t task, BOOL fullScan) {
    NSMutableArray<NSValue *> *regions = [NSMutableArray array];
    mach_vm_address_t address = 0;
    natural_t depth = 0;

    while (1) {
        mach_vm_size_t size = 0;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t infoCount = VM_REGION_SUBMAP_INFO_COUNT_64;
        kern_return_t kr = mach_vm_region_recurse(task, &address, &size, &depth,
                                                    (vm_region_recurse_info_t)&info, &infoCount);
        if (kr != KERN_SUCCESS) break;

        if (info.is_submap) {
            depth += 1;
            continue;
        }

        BOOL writable = (info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE);
        if (writable) {
            // 匿名(malloc系)領域かどうか: 外部ページャ(ファイルマップ等)を持たないプライベートな領域。
            BOOL isAnonymous = (info.share_mode == SM_PRIVATE) && (info.external_pager == 0);
            if (fullScan || isAnonymous) {
                MERegion r = { address, size };
                [regions addObject:[NSValue valueWithBytes:&r objCType:@encode(MERegion)]];
            }
        }

        address += size;
    }

    return regions;
}

#pragma mark - MemScanner

@implementation MemScanner

+ (instancetype)sharedScanner {
    static MemScanner *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MemScanner alloc] init];
    });
    return instance;
}

- (NSArray<MEMatch *> *)scanForValueString:(NSString *)valueString
                                       type:(MEValueType)type
                                   fullScan:(BOOL)fullScan {
    NSData *needleData = MEBytesFromValueString(valueString, type);
    if (needleData.length == 0) return @[];

    const uint8_t *needle = needleData.bytes;
    NSUInteger needleLen = needleData.length;
    NSUInteger stride = (type == MEValueTypeString) ? 1 : needleLen;

    task_t task = mach_task_self();
    NSArray<NSValue *> *regions = MEEnumerateRegions(task, fullScan);
    NSMutableArray<MEMatch *> *results = [NSMutableArray array];

    const mach_vm_size_t kChunkSize = 4 * 1024 * 1024; // 4MB単位で読み込む

    for (NSValue *regionValue in regions) {
        MERegion region;
        [regionValue getValue:&region];

        mach_vm_size_t offset = 0;
        while (offset < region.size) {
            mach_vm_size_t remaining = region.size - offset;
            mach_vm_size_t wantSize = MIN(kChunkSize, remaining);
            // 境界をまたぐ一致を拾うため、末尾に needleLen-1 バイトの重なりを持たせる。
            mach_vm_size_t overlap = (needleLen > 0) ? (needleLen - 1) : 0;
            mach_vm_size_t readSize = MIN(wantSize + overlap, remaining);

            vm_offset_t dataPtr = 0;
            mach_msg_type_number_t dataCount = 0;
            kern_return_t kr = mach_vm_read(task, region.address + offset, readSize, &dataPtr, &dataCount);
            if (kr == KERN_SUCCESS) {
                const uint8_t *buf = (const uint8_t *)dataPtr;
                mach_vm_size_t scanLimit = MIN((mach_vm_size_t)wantSize, dataCount);

                for (mach_vm_size_t i = 0; i + needleLen <= dataCount && i < scanLimit; i += stride) {
                    BOOL matched;
                    if (type == MEValueTypeString) {
                        matched = memcmp(buf + i, needle, needleLen) == 0;
                    } else {
                        matched = MEBytesMatch(buf + i, needle, type);
                    }
                    if (matched) {
                        mach_vm_address_t matchAddr = region.address + offset + i;
                        [results addObject:[[MEMatch alloc] initWithAddress:matchAddr type:type]];
                    }
                }

                vm_deallocate(mach_task_self(), dataPtr, dataCount);
            }

            offset += wantSize;
        }
    }

    return results;
}

- (NSArray<MEMatch *> *)narrowMatches:(NSArray<MEMatch *> *)previousMatches
                          valueString:(NSString *)valueString {
    NSData *needleData = MEBytesFromValueString(valueString, previousMatches.firstObject.type ?: MEValueTypeInt32);
    if (needleData.length == 0) return @[];

    const uint8_t *needle = needleData.bytes;
    NSUInteger needleLen = needleData.length;
    task_t task = mach_task_self();

    NSMutableArray<MEMatch *> *results = [NSMutableArray array];

    for (MEMatch *match in previousMatches) {
        vm_offset_t dataPtr = 0;
        mach_msg_type_number_t dataCount = 0;
        kern_return_t kr = mach_vm_read(task, match.address, needleLen, &dataPtr, &dataCount);
        if (kr == KERN_SUCCESS && dataCount >= needleLen) {
            BOOL matched;
            if (match.type == MEValueTypeString) {
                matched = memcmp((const void *)dataPtr, needle, needleLen) == 0;
            } else {
                matched = MEBytesMatch((const void *)dataPtr, needle, match.type);
            }
            if (matched) {
                [results addObject:match];
            }
        }
        if (dataPtr) {
            vm_deallocate(mach_task_self(), dataPtr, dataCount);
        }
    }

    return results;
}

- (NSArray<MEMatch *> *)scanForRangeMin:(NSString *)minString
                                     max:(NSString *)maxString
                                    type:(MEValueType)type
                                fullScan:(BOOL)fullScan {
    if (type == MEValueTypeString) return @[]; // Stringは範囲検索非対応

    double minValue = strtod(minString.UTF8String ?: "", NULL);
    double maxValue = strtod(maxString.UTF8String ?: "", NULL);
    if (minValue > maxValue) { double tmp = minValue; minValue = maxValue; maxValue = tmp; }

    NSUInteger slotSize = MEValueTypeFixedSize(type);
    if (slotSize == 0) return @[];

    task_t task = mach_task_self();
    NSArray<NSValue *> *regions = MEEnumerateRegions(task, fullScan);
    NSMutableArray<MEMatch *> *results = [NSMutableArray array];

    const mach_vm_size_t kChunkSize = 4 * 1024 * 1024; // 4MB単位で読み込む

    for (NSValue *regionValue in regions) {
        MERegion region;
        [regionValue getValue:&region];

        mach_vm_size_t offset = 0;
        while (offset < region.size) {
            mach_vm_size_t remaining = region.size - offset;
            mach_vm_size_t wantSize = MIN(kChunkSize, remaining);
            mach_vm_size_t overlap = slotSize - 1;
            mach_vm_size_t readSize = MIN(wantSize + overlap, remaining);

            vm_offset_t dataPtr = 0;
            mach_msg_type_number_t dataCount = 0;
            kern_return_t kr = mach_vm_read(task, region.address + offset, readSize, &dataPtr, &dataCount);
            if (kr == KERN_SUCCESS) {
                const uint8_t *buf = (const uint8_t *)dataPtr;
                mach_vm_size_t scanLimit = MIN((mach_vm_size_t)wantSize, dataCount);

                for (mach_vm_size_t i = 0; i + slotSize <= dataCount && i < scanLimit; i += slotSize) {
                    double v = MEDoubleFromBytes(buf + i, type);
                    if (v >= minValue && v <= maxValue) {
                        mach_vm_address_t matchAddr = region.address + offset + i;
                        [results addObject:[[MEMatch alloc] initWithAddress:matchAddr type:type]];
                    }
                }

                vm_deallocate(mach_task_self(), dataPtr, dataCount);
            }

            offset += wantSize;
        }
    }

    return results;
}

- (NSArray<MEMatch *> *)narrowMatchesForRange:(NSArray<MEMatch *> *)previousMatches
                                            min:(NSString *)minString
                                            max:(NSString *)maxString {
    double minValue = strtod(minString.UTF8String ?: "", NULL);
    double maxValue = strtod(maxString.UTF8String ?: "", NULL);
    if (minValue > maxValue) { double tmp = minValue; minValue = maxValue; maxValue = tmp; }

    task_t task = mach_task_self();
    NSMutableArray<MEMatch *> *results = [NSMutableArray array];

    for (MEMatch *match in previousMatches) {
        if (match.type == MEValueTypeString) continue;
        NSUInteger slotSize = MEValueTypeFixedSize(match.type);

        vm_offset_t dataPtr = 0;
        mach_msg_type_number_t dataCount = 0;
        kern_return_t kr = mach_vm_read(task, match.address, slotSize, &dataPtr, &dataCount);
        if (kr == KERN_SUCCESS && dataCount >= slotSize) {
            double v = MEDoubleFromBytes((const void *)dataPtr, match.type);
            if (v >= minValue && v <= maxValue) {
                [results addObject:match];
            }
        }
        if (dataPtr) {
            vm_deallocate(mach_task_self(), dataPtr, dataCount);
        }
    }

    return results;
}

- (nullable NSString *)readValueStringAtAddress:(mach_vm_address_t)address type:(MEValueType)type {
    task_t task = mach_task_self();

    if (type == MEValueTypeString) {
        // 文字列は固定長でないため、適当な最大長までNUL終端 or 非表示文字までを読む。
        // 領域境界付近だと大きい長さでの読み取りが丸ごと失敗しうるため、縮めながら再試行する。
        vm_offset_t dataPtr = 0;
        mach_msg_type_number_t dataCount = 0;
        kern_return_t kr = KERN_FAILURE;
        for (NSUInteger tryLen = 128; tryLen >= 8; tryLen /= 2) {
            kr = mach_vm_read(task, address, tryLen, &dataPtr, &dataCount);
            if (kr == KERN_SUCCESS) break;
        }
        if (kr != KERN_SUCCESS) return nil;

        NSUInteger len = 0;
        const uint8_t *buf = (const uint8_t *)dataPtr;
        while (len < dataCount && buf[len] != 0) len++;

        NSString *result = [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding];
        vm_deallocate(mach_task_self(), dataPtr, dataCount);
        return result ?: @"";
    }

    NSUInteger size = MEValueTypeFixedSize(type);
    vm_offset_t dataPtr = 0;
    mach_msg_type_number_t dataCount = 0;
    kern_return_t kr = mach_vm_read(task, address, size, &dataPtr, &dataCount);
    if (kr != KERN_SUCCESS || dataCount < size) return nil;

    NSString *result = MEStringFromBytes((const void *)dataPtr, size, type);
    vm_deallocate(mach_task_self(), dataPtr, dataCount);
    return result;
}

- (BOOL)writeValueString:(NSString *)valueString type:(MEValueType)type atAddress:(mach_vm_address_t)address {
    NSData *bytes = MEBytesFromValueString(valueString, type);
    if (bytes.length == 0) return NO;

    task_t task = mach_task_self();
    kern_return_t kr = mach_vm_write(task, address, (vm_offset_t)bytes.bytes, (mach_msg_type_number_t)bytes.length);
    return kr == KERN_SUCCESS;
}

@end
