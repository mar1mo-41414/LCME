#import "MEResultCell.h"

@interface MEResultCell () <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UITextField *valueField;
@property (nonatomic, strong) UIButton *freezeButton;
@end

@implementation MEResultCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _addressLabel = [[UILabel alloc] init];
        _addressLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        _addressLabel.textColor = [UIColor whiteColor];
        _addressLabel.numberOfLines = 2;
        [self.contentView addSubview:_addressLabel];

        _valueField = [[UITextField alloc] init];
        _valueField.font = [UIFont systemFontOfSize:13];
        _valueField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        _valueField.textColor = [UIColor whiteColor];
        _valueField.borderStyle = UITextBorderStyleRoundedRect;
        _valueField.returnKeyType = UIReturnKeyDone;
        _valueField.delegate = self;
        [self.contentView addSubview:_valueField];

        _freezeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_freezeButton setTitle:@"固定" forState:UIControlStateNormal];
        _freezeButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _freezeButton.layer.cornerRadius = 6;
        _freezeButton.layer.masksToBounds = YES;
        [_freezeButton addTarget:self action:@selector(freezeTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_freezeButton];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat h = self.contentView.bounds.size.height;
    CGFloat freezeW = 56;
    CGFloat valueW = 90;
    CGFloat pad = 6;

    self.addressLabel.frame = CGRectMake(pad, 0, w - freezeW - valueW - pad * 3, h);
    self.valueField.frame = CGRectMake(CGRectGetMaxX(self.addressLabel.frame) + pad, (h - 30) / 2, valueW, 30);
    self.freezeButton.frame = CGRectMake(w - freezeW - pad, (h - 28) / 2, freezeW, 28);
}

- (void)configureWithMatch:(MEMatch *)match currentValueString:(NSString *)valueString frozen:(BOOL)frozen {
    self.match = match;
    self.addressLabel.text = [NSString stringWithFormat:@"0x%llx\n%@", match.address, MEValueTypeName(match.type)];
    if (!self.valueField.isFirstResponder) {
        self.valueField.text = valueString;
    }
    self.frozen = frozen;
    [self updateFreezeAppearance];
}

- (void)updateFreezeAppearance {
    if (self.frozen) {
        [self.freezeButton setTitle:@"固定中" forState:UIControlStateNormal];
        self.freezeButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.8];
        [self.freezeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        [self.freezeButton setTitle:@"固定" forState:UIControlStateNormal];
        self.freezeButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        [self.freezeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
}

- (void)setFrozen:(BOOL)frozen {
    _frozen = frozen;
    [self updateFreezeAppearance];
}

- (void)freezeTapped {
    [self.delegate resultCellDidToggleFreeze:self];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self.delegate resultCell:self didCommitValueString:textField.text ?: @""];
    return YES;
}

@end
