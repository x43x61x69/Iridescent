//
//  ViewController.m
//  Iridescent
//
//  Created by Cai on 08/11/2017.
//  Copyright © 2017 Cai. All rights reserved.
//

#define UIColorFromRGB(rgb)     [UIColor colorWithRed:((CGFloat)((rgb & 0xFF0000) >> 16))/255.f green:((CGFloat)((rgb & 0xFF00) >> 8))/255.f blue:((CGFloat)(rgb & 0xFF))/255.f alpha:1.f]

#define kGradientFactor         M_PI        // Speed things up by multiplying a fixed value.
#define kGradientUpdateInterval 1.f / 60.f  // iPhone screen refresh rate is @60Hz.
#define kDefaultColor0          UIColorFromRGB(0xA9A1A3).CGColor
#define kDefaultColor1          UIColorFromRGB(0xB8C9A3).CGColor
#define kDefaultColor2          UIColorFromRGB(0xB6CCDC).CGColor
#define kDefaultColor3          UIColorFromRGB(0xA4A8DE).CGColor
#define kAlternateColor         UIColorFromRGB(0xA16DBF).CGColor
#define kBackgroundColors       @[(id)[UIColorFromRGB(0x141414) CGColor], (id)[UIColorFromRGB(0x030303) CGColor]]

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>

#import "CCARadialGradientLayer.h"

@interface ViewController ()

@property (strong, nonatomic)   CMMotionManager *motionManager;
@property (nonatomic)           CMAttitude *referenceAttitude;
@property (strong, nonatomic)   CCARadialGradientLayer *gradientLayer;

@property (weak, nonatomic) IBOutlet UILabel *payLabel;
@property (weak, nonatomic) IBOutlet UILabel *cashLabel;
@property (weak, nonatomic) IBOutlet UILabel *valueLabel;

@property (weak, nonatomic) IBOutlet UIView *cardView;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UILabel *logView;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _payLabel.textColor =
    _cashLabel.textColor =
    _valueLabel.textColor = [UIColor whiteColor];
    _cardView.layer.backgroundColor = [UIColor clearColor].CGColor;
    
    _resetButton.layer.cornerRadius = 4;
    _resetButton.layer.borderWidth = 1;
    _resetButton.layer.borderColor = _resetButton.tintColor.CGColor;
    
    [self setup];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
}

- (void)dealloc
{
    if (_motionManager &&
        [_motionManager isDeviceMotionActive]) {
        [_motionManager stopDeviceMotionUpdates];
    }
}

#pragma mark - Misc

- (void)setup
{
    CAGradientLayer *cardGradientLayer = [CAGradientLayer new];
    cardGradientLayer.frame         = _cardView.bounds;
    cardGradientLayer.colors        = kBackgroundColors;
    cardGradientLayer.cornerRadius  = 10;
    [_cardView.layer insertSublayer:cardGradientLayer
                            atIndex:0];
    
    CALayer *imageLayer = [CALayer new];
    imageLayer.frame = _cardView.bounds;
    imageLayer.contents = (__bridge id _Nullable)([[UIImage imageNamed:@"mask"] CGImage]);
    
    // Apple might be using CGContextDrawRadialGradient for the radial gradient.
    // We have to subclass CALayer to have this done in the future.
    _gradientLayer = [CCARadialGradientLayer new];
    _gradientLayer.frame = _cardView.bounds;
    _gradientLayer.colors = @[(id)kAlternateColor];
    _gradientLayer.mask = imageLayer;
    
    [_cardView.layer addSublayer:_gradientLayer];
}

- (void)motionManagerSetup
{
    _motionManager = [CMMotionManager new];
    
    if ([_motionManager isDeviceMotionAvailable]) {
        if (![_motionManager isDeviceMotionActive]) {
            _motionManager.deviceMotionUpdateInterval = kGradientUpdateInterval;
            
            // Create an operation queue for the motion handler.
            // Using main queue could result in UI lagging.
            NSOperationQueue *motionQueue = [NSOperationQueue new];
            [_motionManager startDeviceMotionUpdatesToQueue:motionQueue
                                                            withHandler:^(CMDeviceMotion *motion,
                                                                          NSError *error)
             {
                 if (!error &&
                     motion) {
                     if (!_referenceAttitude) {
                         // Before the CMMotionManager started, we can't have
                         // any attitude as reference. Assigning the reference
                         // attitude if the it was nil.
                         _referenceAttitude = _motionManager.deviceMotion.attitude;
                     } else {
                         CMAttitude *currentAttitude = motion.attitude;
                         [currentAttitude multiplyByInverseOfAttitude:_referenceAttitude];
                         // Generate gradient with releated attitude.
                         [self gradientWithAttitude:currentAttitude];
                     }
                 }
             }];
        }
    } else {
        _logView.text = @"Gyroscope is unavailable.";
    }
}

- (void)stop
{
    if (_motionManager &&
        [_motionManager isDeviceMotionActive]) {
        [_motionManager stopDeviceMotionUpdates];
        _motionManager = nil;
    }
}

- (void)gradientWithAttitude:(CMAttitude *)attitude
{
    if (!attitude ||
        !_gradientLayer) {
        return;
    }
    
    const CGFloat xf = 1 - (MIN(1, MAX(-1, attitude.roll / M_PI * kGradientFactor)) + 1) / 2;
    const CGFloat gf = MIN(1, sqrtf((powf(attitude.roll, 2) + powf(attitude.pitch * cos(attitude.yaw), 2))) / M_PI * kGradientFactor);
    
    // We were called from motionQueue, UI update must be done within the
    // mainQueue. Switch to mainQueue.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // Disable CATransaction update to prevent lagging in mainQueue.
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue
                         forKey:kCATransactionDisableActions];
        _gradientLayer.locations = @[@0, @(1 - gf), @(1 - gf * .25), @(1 - gf * .5), @(1 - gf * .75), @1];
        _gradientLayer.colors = @[(id)kAlternateColor,
                                  (id)kAlternateColor,
                                  (id)kDefaultColor0,
                                  (id)kDefaultColor1,
                                  (id)kDefaultColor2,
                                  (id)kDefaultColor3];
        _gradientLayer.gradientOrigin = CGPointMake(CGRectGetMaxX(_gradientLayer.bounds) * xf,
                                                    CGRectGetMaxY(_gradientLayer.bounds));
        _gradientLayer.gradientRadius = sqrtf(powf(xf >= .5 ? _gradientLayer.gradientOrigin.x : CGRectGetMaxX(_gradientLayer.bounds) - _gradientLayer.gradientOrigin.x, 2) +
                                              powf(_gradientLayer.gradientOrigin.y, 2));
        // Update CATransaction.
        [CATransaction commit];
        
        _logView.text = [NSString stringWithFormat:
                         @"Motion: %.02f, %.02f, %.02f\n"
                         @"Gradient: %.02f",
                         attitude.pitch,
                         attitude.roll,
                         attitude.yaw,
                         gf];
    }];
}

#pragma mark - NSNotification

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    _referenceAttitude = nil;
    [self motionManagerSetup];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self stop];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - IBAction

- (IBAction)resetReference:(id)sender
{
    _referenceAttitude = nil;
}

@end
