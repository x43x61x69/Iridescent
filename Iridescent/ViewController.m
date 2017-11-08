//
//  ViewController.m
//  Iridescent
//
//  Created by Cai on 08/11/2017.
//  Copyright © 2017 Cai. All rights reserved.
//

#define kGradientUpdateInterval 1.f / 60.f // Screen refresh rate = 60Hz
#define kGradientFactor         2.f
#define kOUR                    93.f
#define kOUG                    222.f
#define kOUB                    236.f
#define kOLR                    212.f
#define kOLG                    157.f
#define kOLB                    99.f
#define kAUR                    158.f
#define kAUG                    137.f
#define kAUB                    226.f
#define kALR                    130.f
#define kALG                    89.f
#define kALB                    145.f
#define kDefaultColors          @[(id)[UIColorFromRGB(0x9E89E2) CGColor], (id)[UIColorFromRGB(0x825991) CGColor]]
#define kBackgroundColors       @[(id)[UIColorFromRGB(0x141414) CGColor], (id)[UIColorFromRGB(0x030303) CGColor]]

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface ViewController ()

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

- (void)gradientWithAttitude:(CMAttitude *)attitude
{
    if (!attitude) {
        return;
    }
    
    CGFloat f = (CGFloat)(MIN(1.f, fabs(attitude.pitch + attitude.roll + attitude.yaw) * _factorSlider.value / M_PI));
    
    CGFloat xU, yU, zU, xL, yL, zL;
    
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
        NSLog(@"Gyroscope is unavailable.");
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    _referenceAttitude = nil;
}

- (void)dealloc
{
    if (_motionManager &&
        [_motionManager isDeviceMotionActive]) {
        [_motionManager stopDeviceMotionUpdates];
    }
}

@end
