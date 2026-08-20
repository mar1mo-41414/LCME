#import "MEOverlayViewController.h"
#import "MEResultCell.h"
#import "MemScanner.h"
#import "FreezeManager.h"
#import "MEDefs.h"

static NSString *const kCellReuseID = @"MEResultCell";

@interface MEOverlayViewController () <UITableViewDataSource, UITableViewDelegate, MEResultCellDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *typeButton;
@property (nonatomic, strong) UISwitch *fullScanSwitch;
@property (nonatomic, strong) UILabel *fullScanLabel;
@property (nonatomic, strong) UISwitch *rangeSwitch;
@property (nonatomic, strong) UILabel *rangeLabel;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UITextField *maxValueField;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *narrowButton;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UIButton *addAddressButton;
@property (nonatomic, strong) UIButton *freezeMasterButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, assign) MEValueType currentType;
@property (nonatomic, strong) NSArray<MEMatch *> *matches;
@property (nonatomic, assign) BOOL panelExpanded;
@property (nonatomic, assign) BOOL isBusy;
@property (nonatomic, weak) NSTimer *livePollTimer;

@end

@implementation MEOverlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.currentType = MEValueTypeInt32;
    self.matches = @[];

    [self buildToggleButton];
    [self buildPanel];
    self.panelView.hidden = YES;
}

#pragma mark - トグルボタン(常時表示・ドラッグ可能)

- (void)buildToggleButton {
    CGFloat size = 56;
    CGRect screen = self.view.bounds;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(screen.size.width - size - 12, screen.size.height * 0.3, size, size);
    button.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.7];
    button.layer.cornerRadius = size / 2;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.3].CGColor;
    [button setTitle:@"M" forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;

    // ドラッグはPanGestureRecognizerで処理する。純粋なタップ(移動なし)は
    // PanGestureRecognizerでは最小移動量を超えないとBegan/Endedへ遷移せず
    // コールバックが一切呼ばれないため、タップの検知はUIButton標準の
    // touchUpInsideに任せる(ボタンの見た目のハイライトもこれと連動する)。
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTogglePan:)];
    [button addGestureRecognizer:pan];
    [button addTarget:self action:@selector(toggleExpanded) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];
    self.toggleButton = button;
}

- (void)handleTogglePan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    CGPoint translation = [pan translationInView:self.view];

    if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint center = view.center;
        center.x += translation.x;
        center.y += translation.y;
        view.center = center;
        [pan setTranslation:CGPointZero inView:self.view];
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        [self clampViewToScreen:view];
    }
}

- (void)clampViewToScreen:(UIView *)view {
    CGRect screen = self.view.bounds;
    CGRect frame = view.frame;
    CGFloat x = MAX(0, MIN(frame.origin.x, screen.size.width - frame.size.width));
    CGFloat y = MAX(0, MIN(frame.origin.y, screen.size.height - frame.size.height));
    view.frame = CGRectMake(x, y, frame.size.width, frame.size.height);
}

- (void)toggleExpanded {
    self.panelExpanded = !self.panelExpanded;
    self.panelView.hidden = !self.panelExpanded;
    self.toggleButton.hidden = self.panelExpanded;
    if (self.panelExpanded) {
        [self clampViewToScreen:self.panelView];
        [self reloadResultsPreservingSelection];
        [self startLivePolling];
    } else {
        // パネルを隠してもfirstResponderが残っているとキーボードが閉じないため明示的に解除する。
        [self.panelView endEditing:YES];
        [self stopLivePolling];
    }
}

#pragma mark - 値の変動追跡(表示中の候補一覧を定期的に読み直す)

- (void)startLivePolling {
    [self stopLivePolling];
    self.livePollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                            target:self
                                                          selector:@selector(livePollTick)
                                                          userInfo:nil
                                                           repeats:YES];
}

- (void)stopLivePolling {
    [self.livePollTimer invalidate];
    self.livePollTimer = nil;
}

- (void)livePollTick {
    if (self.isBusy || self.matches.count == 0) return;
    [self.tableView reloadData];
}

#pragma mark - パネル本体

- (void)buildPanel {
    CGFloat width = 300;
    CGFloat height = 520;
    CGRect screen = self.view.bounds;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(screen.size.width - width - 12, 80, width, height)];
    panel.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:0.92];
    panel.layer.cornerRadius = 14;
    panel.layer.masksToBounds = YES;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    panel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:panel];
    self.panelView = panel;

    CGFloat pad = 10;
    CGFloat y = 0;

    // ヘッダー(ドラッグハンドル)
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 36)];
    header.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    [panel addSubview:header];
    self.headerView = header;
    UIPanGestureRecognizer *headerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [header addGestureRecognizer:headerPan];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, 0, width - 50, 36)];
    title.text = @"LC Mem Editor";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:14];
    [header addSubview:title];
    self.titleLabel = title;

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(width - 40, 0, 36, 36);
    [close setTitle:@"—" forState:UIControlStateNormal];
    close.tintColor = [UIColor whiteColor];
    [close addTarget:self action:@selector(toggleExpanded) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:close];
    self.closeButton = close;

    y = 44;

    // 型選択 + 全領域スキャン
    UIButton *typeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    typeButton.frame = CGRectMake(pad, y, 100, 30);
    [self styleSecondaryButton:typeButton];
    [typeButton addTarget:self action:@selector(typeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:typeButton];
    self.typeButton = typeButton;
    [self updateTypeButtonTitle];

    UISwitch *fullScanSwitch = [[UISwitch alloc] init];
    fullScanSwitch.frame = CGRectMake(width - pad - 51, y, 51, 30);
    fullScanSwitch.onTintColor = [UIColor systemOrangeColor];
    [panel addSubview:fullScanSwitch];
    self.fullScanSwitch = fullScanSwitch;

    UILabel *fullScanLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - pad - 51 - 74, y + 6, 70, 18)];
    fullScanLabel.text = @"全領域";
    fullScanLabel.font = [UIFont systemFontOfSize:11];
    fullScanLabel.textColor = [UIColor lightGrayColor];
    fullScanLabel.textAlignment = NSTextAlignmentRight;
    [panel addSubview:fullScanLabel];
    self.fullScanLabel = fullScanLabel;

    y += 34;

    // 範囲検索トグル(値が常に変動する対象向け。min <= 値 <= max で候補を探す)
    UISwitch *rangeSwitch = [[UISwitch alloc] init];
    rangeSwitch.frame = CGRectMake(width - pad - 51, y, 51, 30);
    rangeSwitch.onTintColor = [UIColor systemGreenColor];
    [rangeSwitch addTarget:self action:@selector(rangeSwitchChanged) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:rangeSwitch];
    self.rangeSwitch = rangeSwitch;

    UILabel *rangeLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad, y + 6, width - pad * 2 - 51 - 8, 18)];
    rangeLabel.text = @"範囲検索(String非対応)";
    rangeLabel.font = [UIFont systemFontOfSize:11];
    rangeLabel.textColor = [UIColor lightGrayColor];
    [panel addSubview:rangeLabel];
    self.rangeLabel = rangeLabel;

    y += 40;

    // 値入力欄(範囲検索ONの場合は左半分=最小値・右半分=最大値の2欄になる)
    UITextField *valueField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, width - pad * 2, 34)];
    valueField.placeholder = @"検索する値";
    valueField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    valueField.textColor = [UIColor whiteColor];
    valueField.borderStyle = UITextBorderStyleRoundedRect;
    valueField.keyboardType = UIKeyboardTypeASCIICapable;
    valueField.returnKeyType = UIReturnKeySearch;
    valueField.delegate = self;
    [panel addSubview:valueField];
    self.valueField = valueField;

    UITextField *maxValueField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, width - pad * 2, 34)];
    maxValueField.placeholder = @"最大値";
    maxValueField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    maxValueField.textColor = [UIColor whiteColor];
    maxValueField.borderStyle = UITextBorderStyleRoundedRect;
    maxValueField.keyboardType = UIKeyboardTypeASCIICapable;
    maxValueField.returnKeyType = UIReturnKeySearch;
    maxValueField.delegate = self;
    maxValueField.hidden = YES;
    [panel addSubview:maxValueField];
    self.maxValueField = maxValueField;

    y += 42;

    // 検索・絞込ボタン
    UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    searchButton.frame = CGRectMake(pad, y, (width - pad * 3) / 2, 34);
    [searchButton setTitle:@"検索(新規)" forState:UIControlStateNormal];
    [self stylePrimaryButton:searchButton];
    [searchButton addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:searchButton];
    self.searchButton = searchButton;

    UIButton *narrowButton = [UIButton buttonWithType:UIButtonTypeSystem];
    narrowButton.frame = CGRectMake(CGRectGetMaxX(searchButton.frame) + pad, y, (width - pad * 3) / 2, 34);
    [narrowButton setTitle:@"絞込" forState:UIControlStateNormal];
    [self stylePrimaryButton:narrowButton];
    narrowButton.enabled = NO;
    [narrowButton addTarget:self action:@selector(narrowTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:narrowButton];
    self.narrowButton = narrowButton;

    y += 42;

    // アドレス直接指定(検索を介さず特定アドレスを候補一覧に追加し、変動追跡・編集を行う)
    UITextField *addressField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, width - pad * 3 - 70, 34)];
    addressField.placeholder = @"0xアドレス直接指定";
    addressField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    addressField.textColor = [UIColor whiteColor];
    addressField.borderStyle = UITextBorderStyleRoundedRect;
    addressField.keyboardType = UIKeyboardTypeASCIICapable;
    addressField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    addressField.autocorrectionType = UITextAutocorrectionTypeNo;
    addressField.returnKeyType = UIReturnKeyDone;
    addressField.delegate = self;
    [panel addSubview:addressField];
    self.addressField = addressField;

    UIButton *addAddressButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addAddressButton.frame = CGRectMake(CGRectGetMaxX(addressField.frame) + pad, y, 70 - pad, 34);
    [addAddressButton setTitle:@"追加" forState:UIControlStateNormal];
    [self stylePrimaryButton:addAddressButton];
    [addAddressButton addTarget:self action:@selector(addAddressTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:addAddressButton];
    self.addAddressButton = addAddressButton;

    y += 42;

    // フリーズ全体トグル
    UIButton *freezeMaster = [UIButton buttonWithType:UIButtonTypeSystem];
    freezeMaster.frame = CGRectMake(pad, y, width - pad * 2, 34);
    [self stylePrimaryButton:freezeMaster];
    [freezeMaster addTarget:self action:@selector(freezeMasterTapped) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:freezeMaster];
    self.freezeMasterButton = freezeMaster;
    [self updateFreezeMasterTitle];

    y += 42;

    // ステータス表示
    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, width - pad * 2, 18)];
    status.font = [UIFont systemFontOfSize:11];
    status.textColor = [UIColor lightGrayColor];
    status.text = @"値を入力して検索してください";
    [panel addSubview:status];
    self.statusLabel = status;

    y += 22;

    // 結果テーブル
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, y, width, height - y) style:UITableViewStylePlain];
    tableView.backgroundColor = [UIColor clearColor];
    tableView.separatorColor = [UIColor colorWithWhite:1 alpha:0.1];
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.rowHeight = 46;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [tableView registerClass:[MEResultCell class] forCellReuseIdentifier:kCellReuseID];
    [panel addSubview:tableView];
    self.tableView = tableView;

    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [UIColor whiteColor];
    spinner.center = panel.center;
    spinner.hidesWhenStopped = YES;
    [panel addSubview:spinner];
    self.spinner = spinner;
}

- (void)styleSecondaryButton:(UIButton *)button {
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    button.tintColor = [UIColor whiteColor];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    button.layer.cornerRadius = 6;
}

- (void)stylePrimaryButton:(UIButton *)button {
    button.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.85];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 6;
}

- (void)handlePanelPan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint center = self.panelView.center;
        center.x += translation.x;
        center.y += translation.y;
        self.panelView.center = center;
        [pan setTranslation:CGPointZero inView:self.view];
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        [self clampViewToScreen:self.panelView];
    }
}

#pragma mark - 型選択

- (void)updateTypeButtonTitle {
    [self.typeButton setTitle:[NSString stringWithFormat:@"型: %@ ▾", MEValueTypeName(self.currentType)] forState:UIControlStateNormal];
}

- (void)typeButtonTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"型を選択" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.popoverPresentationController.sourceView = self.typeButton;
    sheet.popoverPresentationController.sourceRect = self.typeButton.bounds;

    for (NSNumber *typeNumber in MEAllValueTypes()) {
        MEValueType type = typeNumber.integerValue;
        [sheet addAction:[UIAlertAction actionWithTitle:MEValueTypeName(type) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.currentType = type;
            [self updateTypeButtonTitle];
            if (type == MEValueTypeString && self.rangeSwitch.isOn) {
                self.rangeSwitch.on = NO;
                [self updateValueFieldLayout];
                self.statusLabel.text = @"String型は範囲検索に対応していません";
            }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - 範囲検索トグル

- (void)rangeSwitchChanged {
    if (self.rangeSwitch.isOn && self.currentType == MEValueTypeString) {
        self.rangeSwitch.on = NO;
        self.statusLabel.text = @"String型は範囲検索に対応していません";
        return;
    }
    [self updateValueFieldLayout];
}

- (void)updateValueFieldLayout {
    BOOL range = self.rangeSwitch.isOn;
    CGFloat fullWidth = self.valueField.superview.bounds.size.width;
    CGFloat pad = 10;
    CGFloat y = self.valueField.frame.origin.y;
    CGFloat h = self.valueField.frame.size.height;

    if (range) {
        CGFloat halfWidth = (fullWidth - pad * 3) / 2;
        self.valueField.frame = CGRectMake(pad, y, halfWidth, h);
        self.valueField.placeholder = @"最小値";
        self.maxValueField.frame = CGRectMake(pad * 2 + halfWidth, y, halfWidth, h);
        self.maxValueField.hidden = NO;
    } else {
        self.valueField.frame = CGRectMake(pad, y, fullWidth - pad * 2, h);
        self.valueField.placeholder = @"検索する値";
        self.maxValueField.hidden = YES;
        [self.maxValueField resignFirstResponder];
    }
}

#pragma mark - 検索・絞込

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField == self.addressField) {
        [self addAddressTapped];
    } else {
        [self searchTapped];
    }
    return YES;
}

- (void)setUIBusy:(BOOL)busy {
    self.isBusy = busy;
    self.searchButton.enabled = !busy;
    self.narrowButton.enabled = !busy && self.matches.count > 0;
    self.typeButton.enabled = !busy;
    if (busy) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

#pragma mark - アドレス直接指定

- (void)addAddressTapped {
    [self.addressField resignFirstResponder];

    NSString *text = [self.addressField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([text hasPrefix:@"0x"] || [text hasPrefix:@"0X"]) {
        text = [text substringFromIndex:2];
    }
    if (text.length == 0) {
        self.statusLabel.text = @"アドレスを入力してください";
        return;
    }

    const char *cstr = text.UTF8String;
    char *endPtr = NULL;
    mach_vm_address_t address = (mach_vm_address_t)strtoull(cstr, &endPtr, 16);
    BOOL consumedAnyDigit = endPtr != cstr;
    BOOL consumedAllInput = endPtr != NULL && *endPtr == '\0';
    if (!consumedAnyDigit || !consumedAllInput) {
        self.statusLabel.text = @"アドレスの形式が正しくありません(16進数で入力)";
        return;
    }

    MEValueType type = self.currentType;
    NSMutableArray<MEMatch *> *updated = [self.matches mutableCopy] ?: [NSMutableArray array];
    // 同一アドレス・型が既にあれば重複追加しない。
    for (MEMatch *existing in updated) {
        if (existing.address == address && existing.type == type) {
            self.statusLabel.text = @"既に一覧に追加済みです";
            return;
        }
    }
    [updated insertObject:[[MEMatch alloc] initWithAddress:address type:type] atIndex:0];
    self.matches = updated;
    [self.tableView reloadData];
    self.narrowButton.enabled = self.matches.count > 0;
    self.statusLabel.text = [NSString stringWithFormat:@"0x%llx を追加しました", address];
}

- (void)searchTapped {
    [self.valueField resignFirstResponder];
    [self.maxValueField resignFirstResponder];

    BOOL range = self.rangeSwitch.isOn;
    NSString *value = self.valueField.text ?: @"";
    NSString *maxValue = self.maxValueField.text ?: @"";
    if (value.length == 0 || (range && maxValue.length == 0)) {
        self.statusLabel.text = range ? @"最小値・最大値を入力してください" : @"値を入力してください";
        return;
    }
    MEValueType type = self.currentType;
    BOOL fullScan = self.fullScanSwitch.isOn;

    [self setUIBusy:YES];
    self.statusLabel.text = @"検索中…";

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<MEMatch *> *results = range
            ? [[MemScanner sharedScanner] scanForRangeMin:value max:maxValue type:type fullScan:fullScan]
            : [[MemScanner sharedScanner] scanForValueString:value type:type fullScan:fullScan];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.matches = results;
            [self.tableView reloadData];
            self.statusLabel.text = [NSString stringWithFormat:@"%lu件ヒット", (unsigned long)results.count];
            [self setUIBusy:NO];
        });
    });
}

- (void)narrowTapped {
    [self.valueField resignFirstResponder];
    [self.maxValueField resignFirstResponder];

    BOOL range = self.rangeSwitch.isOn;
    NSString *value = self.valueField.text ?: @"";
    NSString *maxValue = self.maxValueField.text ?: @"";
    if (value.length == 0 || (range && maxValue.length == 0) || self.matches.count == 0) return;

    NSArray<MEMatch *> *previous = self.matches;
    [self setUIBusy:YES];
    self.statusLabel.text = @"絞込中…";

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<MEMatch *> *results = range
            ? [[MemScanner sharedScanner] narrowMatchesForRange:previous min:value max:maxValue]
            : [[MemScanner sharedScanner] narrowMatches:previous valueString:value];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.matches = results;
            [self.tableView reloadData];
            self.statusLabel.text = [NSString stringWithFormat:@"%lu件に絞込", (unsigned long)results.count];
            [self setUIBusy:NO];
        });
    });
}

- (void)reloadResultsPreservingSelection {
    [self.tableView reloadData];
}

#pragma mark - フリーズ

- (void)updateFreezeMasterTitle {
    BOOL running = FreezeManager.sharedManager.isRunning;
    [self.freezeMasterButton setTitle:running ? @"フリーズ実行中(タップで停止)" : @"フリーズ停止中(タップで再生)" forState:UIControlStateNormal];
    self.freezeMasterButton.backgroundColor = running
        ? [UIColor colorWithRed:0.9 green:0.3 blue:0.2 alpha:0.85]
        : [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.85];
}

- (void)freezeMasterTapped {
    FreezeManager.sharedManager.running = !FreezeManager.sharedManager.isRunning;
    [self updateFreezeMasterTitle];
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.matches.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEResultCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseID forIndexPath:indexPath];
    MEMatch *match = self.matches[indexPath.row];
    cell.delegate = self;
    NSString *currentValue = [[MemScanner sharedScanner] readValueStringAtAddress:match.address type:match.type] ?: @"?";
    BOOL frozen = [FreezeManager.sharedManager entryForAddress:match.address] != nil;
    [cell configureWithMatch:match currentValueString:currentValue frozen:frozen];
    return cell;
}

#pragma mark - MEResultCellDelegate

- (void)resultCell:(MEResultCell *)cell didCommitValueString:(NSString *)valueString {
    MEMatch *match = cell.match;
    if (!match) return;
    BOOL ok = [[MemScanner sharedScanner] writeValueString:valueString type:match.type atAddress:match.address];
    if (ok) {
        MEFreezeEntry *frozenEntry = [FreezeManager.sharedManager entryForAddress:match.address];
        if (frozenEntry) {
            frozenEntry.valueString = valueString;
        }
        self.statusLabel.text = @"書き込みました";
    } else {
        self.statusLabel.text = @"書き込みに失敗しました";
    }
}

- (void)resultCellDidToggleFreeze:(MEResultCell *)cell {
    MEMatch *match = cell.match;
    if (!match) return;

    if ([FreezeManager.sharedManager entryForAddress:match.address]) {
        [FreezeManager.sharedManager removeEntryForAddress:match.address];
        cell.frozen = NO;
    } else {
        NSString *value = [[MemScanner sharedScanner] readValueStringAtAddress:match.address type:match.type] ?: @"0";
        [FreezeManager.sharedManager addAddress:match.address type:match.type valueString:value];
        cell.frozen = YES;
    }
}

@end
