#import <UIKit/UIKit.h>
#import "MemScanner.h"

NS_ASSUME_NONNULL_BEGIN

@class MEResultCell;

@protocol MEResultCellDelegate <NSObject>
- (void)resultCell:(MEResultCell *)cell didCommitValueString:(NSString *)valueString;
- (void)resultCellDidToggleFreeze:(MEResultCell *)cell;
@end

/// 検索結果1行: アドレス+現在値表示、値編集、固定(freeze)トグルを持つセル。
@interface MEResultCell : UITableViewCell

@property (nonatomic, weak, nullable) id<MEResultCellDelegate> delegate;
@property (nonatomic, strong, nullable) MEMatch *match;
@property (nonatomic, assign, getter=isFrozen) BOOL frozen;

- (void)configureWithMatch:(MEMatch *)match currentValueString:(NSString *)valueString frozen:(BOOL)frozen;

@end

NS_ASSUME_NONNULL_END
