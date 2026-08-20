#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 最前面に常駐するオーバーレイ用ウィンドウ。パネル外のタップは背後のアプリへ通過させる。
@interface MEOverlayWindow : UIWindow

/// アプリの起動完了後に一度だけ呼び出し、オーバーレイを表示する。
+ (void)presentOverlay;

@end

NS_ASSUME_NONNULL_END
