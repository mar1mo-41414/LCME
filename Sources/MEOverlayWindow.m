#import "MEOverlayWindow.h"
#import "MEOverlayViewController.h"

@implementation MEOverlayWindow

+ (void)presentOverlay {
    static MEOverlayWindow *window = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        window = [[MEOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1000;
        window.backgroundColor = [UIColor clearColor];
        window.rootViewController = [[MEOverlayViewController alloc] init];
        window.hidden = NO;
    });
}

// パネル・トグルボタン以外の領域へのタップは背後の対象アプリへ通過させる。
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self.rootViewController.view) {
        return nil;
    }
    return hitView;
}

@end
