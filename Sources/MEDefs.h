#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MEValueType) {
    MEValueTypeInt8 = 0,
    MEValueTypeUInt8,
    MEValueTypeInt16,
    MEValueTypeUInt16,
    MEValueTypeInt32,
    MEValueTypeUInt32,
    MEValueTypeInt64,
    MEValueTypeUInt64,
    MEValueTypeFloat,
    MEValueTypeDouble,
    MEValueTypeString,
};

/// UI表示・スキャン順に並んだ全型のリスト
FOUNDATION_EXPORT NSArray<NSNumber *> *MEAllValueTypes(void);

/// 型の表示名(例: "Int32", "Float", "String")
FOUNDATION_EXPORT NSString *MEValueTypeName(MEValueType type);

/// 固定長型のバイトサイズ。String は可変長のため 0 を返す。
FOUNDATION_EXPORT NSUInteger MEValueTypeFixedSize(MEValueType type);

/// float/double の一致判定に用いる許容誤差(絶対値)。GameGuardian的な緩め判定。
FOUNDATION_EXPORT const double MEFloatTolerance;
FOUNDATION_EXPORT const double MEDoubleTolerance;

NS_ASSUME_NONNULL_END
