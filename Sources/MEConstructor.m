#import <UIKit/UIKit.h>
#import "MEOverlayWindow.h"

/// dylibロード時に自動実行され、アプリ起動完了を待ってオーバーレイを表示する。
__attribute__((constructor))
static void MEEntryPoint(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification * _Nonnull note) {
        [MEOverlayWindow presentOverlay];
    }];
}
