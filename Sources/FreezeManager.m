#import "FreezeManager.h"
#import "MemScanner.h"

/// フリーズの再書き込み間隔。短すぎると対象アプリの動作を阻害するため100msとする。
static const NSTimeInterval kFreezeInterval = 0.1;

@implementation MEFreezeEntry

- (instancetype)initWithAddress:(mach_vm_address_t)address type:(MEValueType)type valueString:(NSString *)valueString {
    self = [super init];
    if (self) {
        _address = address;
        _type = type;
        _valueString = [valueString copy];
    }
    return self;
}

@end

@interface FreezeManager ()
@property (nonatomic, strong) NSMutableArray<MEFreezeEntry *> *mutableEntries;
@property (nonatomic, strong, nullable) dispatch_source_t timer;
@end

@implementation FreezeManager

+ (instancetype)sharedManager {
    static FreezeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FreezeManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableEntries = [NSMutableArray array];
    }
    return self;
}

// mutableEntriesはメインスレッド(UI操作)とフリーズ用タイマースレッドの両方から
// アクセスされるため、@synchronizedで排他制御する。

- (NSArray<MEFreezeEntry *> *)entries {
    @synchronized (self) {
        return [self.mutableEntries copy];
    }
}

- (void)addAddress:(mach_vm_address_t)address type:(MEValueType)type valueString:(NSString *)valueString {
    @synchronized (self) {
        MEFreezeEntry *existing = [self entryForAddress:address];
        if (existing) {
            [self.mutableEntries removeObject:existing];
        }
        MEFreezeEntry *entry = [[MEFreezeEntry alloc] initWithAddress:address type:type valueString:valueString];
        [self.mutableEntries addObject:entry];
    }
}

- (void)removeEntryAtIndex:(NSUInteger)index {
    @synchronized (self) {
        if (index < self.mutableEntries.count) {
            [self.mutableEntries removeObjectAtIndex:index];
        }
    }
}

- (nullable MEFreezeEntry *)entryForAddress:(mach_vm_address_t)address {
    @synchronized (self) {
        for (MEFreezeEntry *entry in self.mutableEntries) {
            if (entry.address == address) return entry;
        }
        return nil;
    }
}

- (void)removeEntryForAddress:(mach_vm_address_t)address {
    @synchronized (self) {
        MEFreezeEntry *existing = [self entryForAddress:address];
        if (existing) {
            [self.mutableEntries removeObject:existing];
        }
    }
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;

    if (running) {
        dispatch_queue_t queue = dispatch_queue_create("me.lcmemeditor.freeze", DISPATCH_QUEUE_SERIAL);
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0),
                                   (uint64_t)(kFreezeInterval * NSEC_PER_SEC), (uint64_t)(0.02 * NSEC_PER_SEC));
        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(timer, ^{
            [weakSelf writeAllEntries];
        });
        dispatch_resume(timer);
        self.timer = timer;
    } else {
        if (self.timer) {
            dispatch_source_cancel(self.timer);
            self.timer = nil;
        }
    }
}

- (void)writeAllEntries {
    // NSMutableArrayはメインスレッド(UI操作)から編集されうるため、スナップショットを取ってから書き込む。
    NSArray<MEFreezeEntry *> *snapshot = self.entries;
    for (MEFreezeEntry *entry in snapshot) {
        [[MemScanner sharedScanner] writeValueString:entry.valueString type:entry.type atAddress:entry.address];
    }
}

@end
