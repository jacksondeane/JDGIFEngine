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
@property (nonatomic, strong) JDGIFEngineOperation *gifOperation;
@end

@implementation JDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.gifEngine = [[JDGIFEngine alloc] init];
}


#pragma mark Actions

- (IBAction)generateGIFFromVideo:(id)sender {
    
    
    
    JDGIFEngine *gifEngine = [JDGIFEngine new];
    JDGIFEngineOperation *operation;
    
    self.gifImageView.image = nil;
    NSURL *videoPath = [[NSBundle mainBundle] URLForResource:@"Miguel_Herrera" withExtension:@"mp4"];
    operation = [gifEngine operationWithVideoURL:videoPath cropStartTime:0 cropEndTime:MAXFLOAT overlayImage:nil previewImage:^(UIImage *previewImage) {
        NSLog(@"previewImage: %@", previewImage);
        self.gifImageView.image = previewImage;
    } completion:^(NSURL *gifURL) {
        NSLog(@"gifURL: %@", gifURL);
        UIImage *gifImage = [UIImage animatedImageWithAnimatedGIFURL:gifURL];
        self.gifImageView.image = gifImage;
    }];
    [gifEngine addOperationToQueue:operation];

}

- (IBAction)generateGIFFromImages:(id)sender {
    
    JDGIFEngine *gifEngine = [JDGIFEngine new];
    JDGIFEngineOperation *operation;
    
    self.gifImageView.image = nil;
    
    
    NSMutableArray *frames = [NSMutableArray new];
    for (int i = 1; i <= 10; i++) {
        NSString *imagePath = [NSString stringWithFormat:@"img%d.jpg", i];
        [frames addObject:[UIImage imageNamed:imagePath]];
    }
    
    operation = [gifEngine operationWithFrames:frames frameDuration:.5 previewImage:^(UIImage *previewImage) {
        NSLog(@"previewImage: %@", previewImage);
        self.gifImageView.image = previewImage;
    } completion:^(NSURL *gifURL) {
        NSLog(@"gifURL: %@", gifURL);
        UIImage *gifImage = [UIImage animatedImageWithAnimatedGIFURL:gifURL];
        self.gifImageView.image = gifImage;
    }];
    [gifEngine addOperationToQueue:operation];
    
}


@end
