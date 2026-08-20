#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import "MEDefs.h"

NS_ASSUME_NONNULL_BEGIN

/// フリーズ対象1件(アドレス・型・固定する値)。
@interface MEFreezeEntry : NSObject
@property (nonatomic, assign, readonly) mach_vm_address_t address;
@property (nonatomic, assign, readonly) MEValueType type;
@property (nonatomic, copy) NSString *valueString;
- (instancetype)initWithAddress:(mach_vm_address_t)address type:(MEValueType)type valueString:(NSString *)valueString;
@end

/// 書き込みループ方式で登録アドレスへ定期的に値を再書き込みし続けるマネージャ。
@interface FreezeManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) NSArray<MEFreezeEntry *> *entries;
@property (nonatomic, assign, getter=isRunning) BOOL running;

- (void)addAddress:(mach_vm_address_t)address type:(MEValueType)type valueString:(NSString *)valueString;
- (void)removeEntryAtIndex:(NSUInteger)index;
- (nullable MEFreezeEntry *)entryForAddress:(mach_vm_address_t)address;
- (void)removeEntryForAddress:(mach_vm_address_t)address;

@end

NS_ASSUME_NONNULL_END
