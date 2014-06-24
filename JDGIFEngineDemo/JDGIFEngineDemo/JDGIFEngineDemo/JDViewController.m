//
//  JDViewController.m
//  JDGIFEngineDemo
//
//  Created by Jackson Deane on 6/24/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import "JDViewController.h"

#import "JDGIFEngine.h"
#import "UIImage+animatedGIF.h"

@interface JDViewController ()
@property (nonatomic, weak) IBOutlet UIImageView *gifImageView;
@property (nonatomic, strong) JDGIFEngine *gifEngine;
@end

@implementation JDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.gifEngine = [[JDGIFEngine alloc] init];
}

- (IBAction)generateGIF:(id)sender {
    self.gifImageView.image = nil;
    NSURL *videoPath = [[NSBundle mainBundle] URLForResource:@"Miguel_Herrera" withExtension:@"mp4"];
    [self.gifEngine generateGIFForVideoPath:videoPath startTime:0.0f endTime:MAXFLOAT completion:^(NSURL *gifURL) {
        UIImage *gifImage = [UIImage animatedImageWithAnimatedGIFURL:gifURL];
        self.gifImageView.image = gifImage;
    }];
}

@end
