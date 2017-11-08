//
//  ViewController.m
//  Iridescent
//
//  Created by Cai on 08/11/2017.
//  Copyright © 2017 Cai. All rights reserved.
//

#define redFromRGB(rgbValue)    ((CGFloat)((rgbValue & 0xFF0000) >> 16))
#define greenFromRGB(rgbValue)  ((CGFloat)((rgbValue & 0xFF00) >> 8))
#define blueFromRGB(rgbValue)   ((CGFloat)(rgbValue & 0xFF))
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((CGFloat)((rgbValue & 0xFF0000) >> 16))/255.f green:((CGFloat)((rgbValue & 0xFF00) >> 8))/255.f blue:((CGFloat)(rgbValue & 0xFF))/255.f alpha:1.0]

#define kGradientUpdateInterval 1.f / 60.f // Screen refresh rate = 60Hz
#define kGradientFactor         2.f
#define kDefaultColorUpper      0x5DDEEC
#define kDefaultColorLower      0xD49D63
#define kAlternateColorUpper    0x9E89E2
#define kAlternateColorLower    0x825991
#define kOUR                    redFromRGB(kDefaultColorUpper)
#define kOUG                    greenFromRGB(kDefaultColorUpper)
#define kOUB                    blueFromRGB(kDefaultColorUpper)
#define kOLR                    redFromRGB(kDefaultColorLower)
#define kOLG                    greenFromRGB(kDefaultColorLower)
#define kOLB                    blueFromRGB(kDefaultColorLower)
#define kAUR                    redFromRGB(kAlternateColorUpper)
#define kAUG                    greenFromRGB(kAlternateColorUpper)
#define kAUB                    blueFromRGB(kAlternateColorUpper)
#define kALR                    redFromRGB(kAlternateColorLower)
#define kALG                    greenFromRGB(kAlternateColorLower)
#define kALB                    blueFromRGB(kAlternateColorLower)
#define kDefaultColors          @[(id)[UIColorFromRGB(kAlternateColorUpper) CGColor], (id)[UIColorFromRGB(kAlternateColorLower) CGColor]]
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
    
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.frame         = _cardView.bounds;
    _gradientLayer.colors        = kDefaultColors;
    
//    CATextLayer *textLayer = [CATextLayer new];
//    textLayer.frame = _gradientLayer.frame;
//    textLayer.string = @"$";
//    textLayer.alignmentMode = kCAAlignmentCenter;
//    textLayer.fontSize = _gradientLayer.frame.size.height * .8f;
//    _gradientLayer.mask = textLayer;
    
    CALayer *imageLayer = [CALayer new];
    imageLayer.frame = _gradientLayer.frame;
    imageLayer.contents = (__bridge id _Nullable)([[UIImage imageNamed:@"mask"] CGImage]);
    _gradientLayer.mask = imageLayer;
    
    [_cardView.layer addSublayer:_gradientLayer];
    
//    [self setup];
    
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
    if (!attitude) {
        return;
    }
    
    CGFloat f, xU, yU, zU, xL, yL, zL;
    
    f = (CGFloat)(fabs(attitude.pitch + attitude.roll + attitude.yaw) / M_PI * _factorSlider.value);
    
    if (f > 1.f) {
        f = 1.f - fmod(f, 1.f);
    }
    
    xU = kAUR + (kOUR - kAUR) * f;
    yU = kAUG + (kOUG - kAUG) * f;
    zU = kAUB + (kOUB - kAUB) * f;
    xL = kALR + (kOLR - kALR) * f;
    yL = kALG + (kOLG - kALG) * f;
    zL = kALB + (kOLB - kALB) * f;
    
    _gradientLayer.colors = @[(id)[[UIColor colorWithRed:xU / 255.f
                                                   green:yU / 255.f
                                                    blue:zU / 255.f
                                                   alpha:1.f] CGColor],
                              (id)[[UIColor colorWithRed:xL / 255.f
                                                   green:yL / 255.f
                                                    blue:zL / 255.f
                                                   alpha:1.f] CGColor]];
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
