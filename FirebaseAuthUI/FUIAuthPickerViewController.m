//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FUIAuthPickerViewController.h"

#import <FirebaseAuth/FirebaseAuth.h>
#import "FUIAuthBaseViewController_Internal.h"
#import "FUIAuthSignInButton.h"
#import "FUIAuthStrings.h"
#import "FUIAuthUtils.h"
#import "FUIAuth_Internal.h"
#import "FUIEmailEntryViewController.h"

/** @var kErrorUserInfoEmailKey
    @brief The key for the email address in the userinfo dictionary of a sign in error.
 */
static NSString *const kErrorUserInfoEmailKey = @"FIRAuthErrorUserInfoEmailKey";

/** @var kEmailButtonAccessibilityID
    @brief The Accessibility Identifier for the @c email sign in button.
 */
static NSString *const kEmailButtonAccessibilityID = @"EmailButtonAccessibilityID";

/** @var kSignInButtonPadding2X
    @brief The horizontal 2x padding of the sign in buttons.
 */
static const CGFloat kSignInButtonPadding2X = 66.5;

/** @var kSignInButtonPadding3X
 @brief The horizontal 3x padding of the sign in buttons.
 */
static const CGFloat kSignInButtonPadding3X = 73;

/** @var kSignInButtonHeight2X
    @brief The 2x height of the sign in buttons.
 */
static const CGFloat kSignInButtonHeight2X = 44.0f;

/** @var kSignInButtonHeight3X
 @brief The 3x height of the sign in buttons.
 */
static const CGFloat kSignInButtonHeight3X = 48.0f;

/** @var kSignInButtonVerticalMargin2x
    @brief The 2x vertical margin between sign in buttons.
 */
static const CGFloat kSignInButtonVerticalMargin2x = 16;

/** @var kSignInButtonVerticalMargin3x
 @brief The 3x vertical margin between sign in buttons.
 */
static const CGFloat kSignInButtonVerticalMargin3x = 17.7;

/** @var kButtonContainerCenterOffset2x
 @brief The 2x center offset.
 */
static const CGFloat kButtonContainerCenterOffset2x = 41;

/** @var kButtonContainerCenterOffset3x
 @brief The 3x center offset.
 */
static const CGFloat kButtonContainerCenterOffset3x = 48.5;

@interface FUIAuthPickerViewController ()
@property (nonatomic, strong) UIView *buttonContainerView;

@end

@implementation FUIAuthPickerViewController

- (instancetype)initWithAuthUI:(FUIAuth *)authUI {
  return [self initWithNibName:NSStringFromClass([self class])
                        bundle:[FUIAuthUtils bundleNamed:FUIAuthBundleName]
                        authUI:authUI];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil
                         bundle:(NSBundle *)nibBundleOrNil
                         authUI:(FUIAuth *)authUI {

  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
                         authUI:authUI];
  if (self) {
    self.title = FUILocalizedString(kStr_AuthPickerTitle);
  }
  return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *cancelBarButton =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(cancelAuthorization)];
    self.navigationItem.leftBarButtonItem = cancelBarButton;
    self.navigationItem.backBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:FUILocalizedString(kStr_Back)
                                     style:UIBarButtonItemStylePlain
                                    target:nil
                                    action:nil];
    
    BOOL is3X = UIScreen.mainScreen.scale > 2;
    
    UIView *view = self.view;
    UIStackView *container = [UIStackView new];
    container.axis = UILayoutConstraintAxisVertical;
    container.spacing = is3X ? kSignInButtonVerticalMargin3x : kSignInButtonVerticalMargin2x;
    self.buttonContainerView = container;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    
    [view addSubview:container];
    
    NSArray *constr = @[[container.leftAnchor constraintEqualToAnchor:view.leftAnchor
                                                             constant:is3X ? kSignInButtonPadding3X : kSignInButtonPadding2X],
                        [container.rightAnchor constraintEqualToAnchor:view.rightAnchor
                                                              constant:-(is3X ? kSignInButtonPadding3X : kSignInButtonPadding2X)],
                        [container.centerYAnchor constraintEqualToAnchor:view.centerYAnchor
                                                              constant:(is3X
                                                                        ? kButtonContainerCenterOffset3x
                                                                        : kButtonContainerCenterOffset2x)]];
    [NSLayoutConstraint activateConstraints:constr];
    
    if (!self.authUI.signInWithEmailHidden) {
        UIColor *emailButtonBackgroundColor =
        [UIColor colorWithRed:35/255.f green:136/255.f blue:196/255.f alpha:1.0];
        UIButton *emailButton =
        [[FUIAuthSignInButton alloc] initWithFrame:CGRectZero
                                             image:nil
                                              text:FUILocalizedString(kStr_Email)
                                   backgroundColor:emailButtonBackgroundColor
                                         textColor:[UIColor whiteColor]];
        [emailButton addTarget:self
                        action:@selector(signInWithEmail)
              forControlEvents:UIControlEventTouchUpInside];
        emailButton.accessibilityIdentifier = kEmailButtonAccessibilityID;
        
        [emailButton.heightAnchor constraintEqualToConstant:(is3X
                                                             ? kSignInButtonHeight3X
                                                             : kSignInButtonHeight2X)].active = YES;
        
        [container addArrangedSubview:emailButton];
    }
    
    for (id<FUIAuthProvider> providerUI in [self.authUI.providers reverseObjectEnumerator]) {
        UIButton *providerButton =
        [[FUIAuthSignInButton alloc] initWithFrame:CGRectZero providerUI:providerUI];
        [providerButton addTarget:self
                           action:@selector(didTapSignInButton:)
                 forControlEvents:UIControlEventTouchUpInside];
        
        [providerButton.heightAnchor constraintEqualToConstant:(is3X
                                                                ? kSignInButtonHeight3X
                                                                : kSignInButtonHeight2X)].active = YES;
        [container addArrangedSubview:providerButton];
    }
}

#pragma mark - Actions

- (void)signInWithEmail {
  UIViewController *controller;
  if ([self.authUI.delegate respondsToSelector:@selector(emailEntryViewControllerForAuthUI:)]) {
    controller = [self.authUI.delegate emailEntryViewControllerForAuthUI:self.authUI];
  } else {
    controller = [[FUIEmailEntryViewController alloc] initWithAuthUI:self.authUI];
  }
  [self pushViewController:controller];
}

- (void)didTapSignInButton:(FUIAuthSignInButton *)button {
  [self.authUI signInWithProviderUI:button.providerUI
           presentingViewController:self
                       defaultValue:nil];
}

@end
