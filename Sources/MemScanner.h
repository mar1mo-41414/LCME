#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "MEDefs.h"

NS_ASSUME_NONNULL_BEGIN

/// 1件のスキャン候補(アドレスと型)。値はキャッシュせず都度メモリから読み直す。
@interface MEMatch : NSObject
@property (nonatomic, assign) mach_vm_address_t address;
@property (nonatomic, assign) MEValueType type;
- (instancetype)initWithAddress:(mach_vm_address_t)address type:(MEValueType)type;
@end

/// 自プロセス(mach_task_self)に対するメモリスキャン・読み書きを担当。
@interface MemScanner : NSObject

+ (instancetype)sharedScanner;

/// 新規スキャン。fullScan=NOの場合は書き込み可能な匿名(malloc系)領域のみを対象にする。
- (NSArray<MEMatch *> *)scanForValueString:(NSString *)valueString
                                       type:(MEValueType)type
                                   fullScan:(BOOL)fullScan;

/// 直前の候補群のうち、現在も指定値に一致するものだけを残す絞り込み検索。
- (NSArray<MEMatch *> *)narrowMatches:(NSArray<MEMatch *> *)previousMatches
                          valueString:(NSString *)valueString;

/// 指定アドレスの現在値を表示用文字列として読み出す。読み取り失敗時はnil。
- (nullable NSString *)readValueStringAtAddress:(mach_vm_address_t)address type:(MEValueType)type;

/// 指定アドレスへ値を書き込む。成功したらYES。
- (BOOL)writeValueString:(NSString *)valueString type:(MEValueType)type atAddress:(mach_vm_address_t)address;

@end

NS_ASSUME_NONNULL_END
