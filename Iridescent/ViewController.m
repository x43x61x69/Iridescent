//
//  ViewController.m
//  Iridescent
//
//  Created by Cai on 08/11/2017.
//  Copyright © 2017 Cai. All rights reserved.
//

#define UIColorFromRGB(rgb)     [UIColor colorWithRed:((CGFloat)((rgb & 0xFF0000) >> 16))/255.f green:((CGFloat)((rgb & 0xFF00) >> 8))/255.f blue:((CGFloat)(rgb & 0xFF))/255.f alpha:1.f]

#define kGradientFactor         M_PI        // A 1/2 attitude (M_PI) is way too large for this effect, speed things up by multiplying a fixed value.
#define kGradientUpdateInterval 1.f / 60.f  // iPhone screen refresh rate is @60Hz.
#define kDefaultColor0          UIColorFromRGB(0xC3FFFA).CGColor
#define kDefaultColor1          UIColorFromRGB(0xB8EFE9).CGColor
#define kDefaultColor2          UIColorFromRGB(0x5DDEEC).CGColor
#define kAlternateColor         UIColorFromRGB(0xC599F1).CGColor
#define kBackgroundColors       @[(id)[UIColorFromRGB(0x141414) CGColor], (id)[UIColorFromRGB(0x030303) CGColor]]

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>

@interface ViewController ()

@property (strong, nonatomic)   CMMotionManager *motionManager;
@property (nonatomic)           CMAttitude *referenceAttitude;
@property (strong, nonatomic)   CAGradientLayer *gradientLayer;

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
    
    _resetButton.layer.cornerRadius = 4.f;
    _resetButton.layer.borderWidth = 1.f;
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
    cardGradientLayer.cornerRadius  = 10.f;
    [_cardView.layer insertSublayer:cardGradientLayer
                            atIndex:0];
    
    CALayer *imageLayer = [CALayer new];
    imageLayer.frame = _cardView.bounds;
    imageLayer.contents = (__bridge id _Nullable)([[UIImage imageNamed:@"mask"] CGImage]);
    
    // Apple might be using CGContextDrawRadialGradient for the radial gradient.
    // We have to subclass CALayer to have this done in the future.
    _gradientLayer = [CAGradientLayer new];
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
    
    const CGFloat xf = MAX(-1, MIN(1, attitude.roll / M_PI * kGradientFactor));
    const CGFloat yf = MIN(1, fabs((MIN(0, attitude.pitch / M_PI * fabs(cos(attitude.yaw)) * kGradientFactor))));
    const CGFloat gf = powf((powf(xf, 2) + powf(yf, 2)), .5) / powf(2, .5) * .95;
    
    const CGFloat xf_mapped = (xf + 1) / 2;
    const CGFloat yf_mapped = MIN(.6, yf);
    
    // We were called from motionQueue, UI update must be done within the
    // mainQueue. Switch to mainQueue.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // Disable CATransaction update to prevent lagging in mainQueue.
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue
                         forKey:kCATransactionDisableActions];
        _gradientLayer.startPoint = CGPointMake(xf_mapped, yf_mapped);
        _gradientLayer.endPoint = CGPointMake(fabs(1 - xf_mapped), 1 + yf_mapped / 2);
        _gradientLayer.locations = @[@0, @(gf * .33), @(gf * .66), @(gf), @1];
        _gradientLayer.colors = @[(id)kDefaultColor0,
                                  (id)kDefaultColor1,
                                  (id)kDefaultColor2,
                                  (id)kAlternateColor,
                                  (id)kAlternateColor];
        // Update CATransaction.
        [CATransaction commit];
        
        _logView.text = [NSString stringWithFormat:@"Motion: %.02f, %.02f, %.02f\nPoints: (%.02f, %.02f) -> (%.02f, %.02f)\nGradient: %.02f (%.02f, %.02f)",
                         attitude.pitch,
                         attitude.roll,
                         attitude.yaw,
                         _gradientLayer.startPoint.x,
                         _gradientLayer.startPoint.y,
                         _gradientLayer.endPoint.x,
                         _gradientLayer.endPoint.y,
                         gf,
                         xf,
                         yf];
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
