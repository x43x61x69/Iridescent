//
//  ViewController.m
//  Iridescent
//
//  Created by Cai on 08/11/2017.
//  Copyright © 2017 Cai. All rights reserved.
//

#define UIColorFromRGB(rgb)     [UIColor colorWithRed:((CGFloat)((rgb & 0xFF0000) >> 16))/255.f green:((CGFloat)((rgb & 0xFF00) >> 8))/255.f blue:((CGFloat)(rgb & 0xFF))/255.f alpha:1.f]

#define kGradientUpdateInterval 1.f / 60.f // Screen refresh rate = 60Hz
#define kGradientFactor         2.f
#define kDefaultColorUpper      0x5DDEEC
#define kDefaultColorLower      0xD49D63
#define kAlternateColorUpper    0x9E89E2
#define kAlternateColorLower    0x825991
#define kDefaultColors          @[(id)[UIColorFromRGB(kDefaultColorUpper) CGColor], (id)[UIColorFromRGB(kDefaultColorLower) CGColor]]
#define kAlternateColors        @[(id)[UIColorFromRGB(kAlternateColorUpper) CGColor], (id)[UIColorFromRGB(kAlternateColorLower) CGColor]]
#define kBackgroundColors       @[(id)[UIColorFromRGB(0x141414) CGColor], (id)[UIColorFromRGB(0x030303) CGColor]]

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface ViewController ()

@property (nonatomic)           CGFloat brightness;

@property (strong, nonatomic)   CMMotionManager *motionManager;
@property (nonatomic)           CMAttitude *referenceAttitude;
@property (strong, nonatomic)   CAGradientLayer *gradientLayer;

@property (weak, nonatomic) IBOutlet UILabel *payLabel;
@property (weak, nonatomic) IBOutlet UILabel *cashLabel;
@property (weak, nonatomic) IBOutlet UILabel *valueLabel;

@property (weak, nonatomic) IBOutlet UIView *cardView;
@property (weak, nonatomic) IBOutlet UILabel *logView;
@property (weak, nonatomic) IBOutlet UISlider *factorSlider;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _payLabel.textColor =
    _cashLabel.textColor =
    _valueLabel.textColor = [UIColor whiteColor];
    _cardView.layer.backgroundColor = [UIColor clearColor].CGColor;
    
    CAGradientLayer *backgroundGradientLayer = [CAGradientLayer layer];
    backgroundGradientLayer.frame         = _cardView.bounds;
    backgroundGradientLayer.colors        = kBackgroundColors;
    backgroundGradientLayer.cornerRadius  = 10.f;
    [_cardView.layer insertSublayer:backgroundGradientLayer atIndex:0];
    
    CAGradientLayer *gradientBackgroundLayer = [CAGradientLayer layer];
    gradientBackgroundLayer.frame = _cardView.bounds;
    gradientBackgroundLayer.colors = kAlternateColors;
    
    CALayer *imageBackgroundLayer = [CALayer new];
    imageBackgroundLayer.frame = gradientBackgroundLayer.frame;
    imageBackgroundLayer.contents = (__bridge id _Nullable)([[UIImage imageNamed:@"mask"] CGImage]);
    gradientBackgroundLayer.mask = imageBackgroundLayer;
    [_cardView.layer addSublayer:gradientBackgroundLayer];
    
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.frame = _cardView.bounds;
    _gradientLayer.colors = kAlternateColors;
    
    CALayer *imageLayer = [CALayer new];
    imageLayer.frame = _gradientLayer.frame;
    imageLayer.contents = (__bridge id _Nullable)([[UIImage imageNamed:@"mask"] CGImage]);
    _gradientLayer.mask = imageLayer;
    [_cardView.layer addSublayer:_gradientLayer];
    
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
    _brightness = [UIScreen mainScreen].brightness;
    
    _motionManager = [CMMotionManager new];
    
    if ([_motionManager isDeviceMotionAvailable]) {
        if (![_motionManager isDeviceMotionActive] &&
            ([CMMotionManager availableAttitudeReferenceFrames] & CMAttitudeReferenceFrameXMagneticNorthZVertical)) {
            _motionManager.deviceMotionUpdateInterval = kGradientUpdateInterval;
            _motionManager.showsDeviceMovementDisplay = YES;
            [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical
                                                                toQueue:[NSOperationQueue mainQueue]
                                                            withHandler:^(CMDeviceMotion *motion,
                                                                          NSError *error)
             {
                 [UIScreen mainScreen].brightness = 1.f;
                 if (!error &&
                     motion) {
                     if (!_referenceAttitude) {
                         _referenceAttitude = _motionManager.deviceMotion.attitude;
                     } else {
                         CMAttitude *currentAttitude = motion.attitude;
                         [currentAttitude multiplyByInverseOfAttitude:_referenceAttitude];
                         [self gradientWithAttitude:currentAttitude];
                         
                         _logView.text = [NSString stringWithFormat:@"Motion: %.02f, %.02f, %.02f\nFactor: %.02f",
                                          currentAttitude.pitch,
                                          currentAttitude.roll,
                                          currentAttitude.yaw,
                                          _factorSlider.value];
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
        [UIScreen mainScreen].brightness = _brightness;
    }
}

- (void)gradientWithAttitude:(CMAttitude *)attitude
{
    if (!attitude ||
        !_gradientLayer) {
        return;
    }
    
    CGFloat xf = (CGFloat)(fabs(attitude.pitch) / M_PI * _factorSlider.value);
    CGFloat yf = (CGFloat)(fabs(attitude.roll) / M_PI * _factorSlider.value);
    CGFloat gf = pow((pow(xf, 2) + pow(yf, 2)), .5);
    
    if (xf > 1.f) {
        xf = 1.f - fmod(xf, 1.f);
    }
    
    if (yf > 1.f) {
        yf = 1.f - fmod(yf, 1.f);
    }
    
    _gradientLayer.startPoint = CGPointMake(xf, yf);
    _gradientLayer.endPoint = CGPointMake(1.f - xf, 1.f - yf);
    _gradientLayer.locations = @[@(gf/2.f), @(gf), @1];
    _gradientLayer.colors = @[(id)[UIColorFromRGB(kDefaultColorUpper) CGColor],
                              (id)[UIColorFromRGB(kDefaultColorLower) CGColor],
                              (id)[[UIColor clearColor] CGColor]];
}

#pragma mark - NSNotification

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    _referenceAttitude = nil;
    [self setup];
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
