//
//  RootViewController.m
//  SimpleCam
//
//  Created by Logan Wright on 3/31/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "RootViewController.h"

@interface RootViewController () <UIActionSheetDelegate>

@property (strong, nonatomic) UIImageView * imgView;
@property (strong, nonatomic) UILabel * tapLabel;
@property (nonatomic,strong) SimpleCam *simpleCam;
@property (nonatomic) BOOL takePhotoImmediately;
@property (strong, nonatomic) UIView * overlayView;

@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _imgView = [UIImageView new];
    _imgView.bounds = CGRectMake(0, 0, 200, 300);
    _imgView.center = self.view.center;
    _imgView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
    _imgView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_imgView];
    
    _tapLabel = [UILabel new];
    _tapLabel.bounds = CGRectMake(0, 0, 200, 100);
    _tapLabel.text = @"TAP TO TAKE PHOTO";
    _tapLabel.textAlignment = NSTextAlignmentCenter;
    _tapLabel.center = self.view.center;
    _tapLabel.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:_tapLabel];
    
    UITapGestureRecognizer * tap = [UITapGestureRecognizer new];
    [tap addTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tap];
}

#pragma mark TAP RECOGNIZER

- (void) handleTap:(UITapGestureRecognizer *)tap {
    SimpleCam * simpleCam = [SimpleCam new];
    simpleCam.delegate= self;
    
    [self presentViewController:simpleCam animated:YES completion:nil];
}

#pragma mark SIMPLE CAM DELEGATE

- (void) simpleCam:(SimpleCam *)simpleCam didFinishWithImage:(UIImage *)image {
    
    if (image) {
        // simple cam finished with image
        
        _imgView.image = image;
        //_tapLabel.hidden = NO;
    }
    else {
        // simple cam finished w/o image
        
        _imgView.image = nil;
        //_tapLabel.hidden = NO;
    }
    
    // Close simpleCam - use this as opposed to 'dismissViewController' otherwise, the captureSession may not close properly and may result in memory leaks.
    [simpleCam closeWithCompletion:^{
        NSLog(@"SimpleCam is done closing ... ");
    }];
}

- (void) simpleCamDidLoadCameraIntoView:(SimpleCam *)simpleCam {
    NSLog(@"Camera loaded ... ");
    
    if (self.takePhotoImmediately) {
        [simpleCam capturePhoto];
    }
}

- (void) simpleCamNotAuthorizedForCameraUse:(SimpleCam *)simpleCam {
    [simpleCam closeWithCompletion:^{
        NSLog(@"SimpleCam is done closing ... Not Authorized");
    }];
}

@end
