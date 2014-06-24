//
//  JDGIFEngine.m
//  JDGIFEngineDemo
//
//  Created by Jackson Deane on 6/24/14.
//  Copyright (c) 2014 Jackson Deane. All rights reserved.
//

#import "JDGIFEngine.h"

#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>


@implementation JDGIFEngine

- (id)init {
    self = [super init];
    if (self != nil) {
        self.framesPerSecond = 10;
        self.maximumSize = CGSizeMake(400.0f, 400.0f);
    }
    return self;
}

- (void)generateGIFForVideoPath:(NSURL*)videoPath completion:(void (^)(NSURL *gifURL))completion {
    [self generateGIFForVideoPath:videoPath startTime:0.0f endTime:MAXFLOAT completion:^(NSURL *gifURL) {
        completion(gifURL);
    }];
}

- (void)generateGIFForVideoPath:(NSURL*)videoPath startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime completion:(void (^)(NSURL *gifURL))completion {
    AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoPath options:nil];
    NSTimeInterval videoDuration = CMTimeGetSeconds([videoAsset duration]);
    NSMutableArray *frames = [NSMutableArray new];
    [self generateFramesForVideoAsset:videoAsset startTime:startTime endTime:endTime frameOutput:^(UIImage *snapshotImage) {
        [frames addObject:snapshotImage];
    } completion:^{
        [self generateGIFWithFrames:frames duration:videoDuration completion:^(NSURL *gifURL) {
            completion(gifURL);
        }];
    }];
}


#pragma mark

- (void)generateFramesForVideoAsset:(AVAsset *)asset startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime frameOutput:(void(^)(UIImage *snapshotImage))frameOutput completion:(void (^)())completion {
    
    dispatch_async(dispatch_queue_create("generator", DISPATCH_QUEUE_SERIAL), ^{
        
        NSTimeInterval normalizedEndTime = MIN(endTime, CMTimeGetSeconds([asset duration]));
        NSTimeInterval videoDuration = normalizedEndTime - startTime;
        NSInteger snapshotCount = ceil(videoDuration * self.framesPerSecond);
        
        NSMutableArray *times = [NSMutableArray array];
        for (NSInteger snapshotIndex = 0; snapshotIndex < snapshotCount; snapshotIndex++) {
            CMTime time = CMTimeMakeWithSeconds(((videoDuration / snapshotCount) * snapshotIndex) + startTime, 1000);
            [times addObject:[NSValue valueWithCMTime:time]];
        }
        
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        __block NSInteger snapshotIndex = 0;
        
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        
        imageGenerator.maximumSize = self.maximumSize;
        
        imageGenerator.appliesPreferredTrackTransform = YES;
        imageGenerator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        
        [imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef cgImage, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
            
            if (result == AVAssetImageGeneratorSucceeded) {
                UIImage *image = [UIImage imageWithCGImage:cgImage];
                dispatch_async(dispatch_get_main_queue(), ^{
                    frameOutput(image);
                });
            } else {
                NSLog(@"Error generating image frames: %@", error);
            }
            
            snapshotIndex++;
            if (snapshotIndex >= snapshotCount) {
                dispatch_semaphore_signal(semaphore);
            }
        }];
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        if (completion != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)generateGIFWithFrames:(NSArray*)frames duration:(NSTimeInterval)duration completion:(void (^)(NSURL *gifURL))completion {
    NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
                                         @{(__bridge id)kCGImagePropertyGIFLoopCount: @0, }
                                     };
    
    CGFloat frameDuration = duration / [frames count];
    NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
                                          @{(__bridge id)kCGImagePropertyGIFDelayTime : @(frameDuration)}
                                      };
    
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *gifURL = [documentsDirectoryURL URLByAppendingPathComponent:@"output.gif"];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, [frames count], NULL);
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
    
    for (UIImage *frame in frames) {
        @autoreleasepool {
            CGImageDestinationAddImage(destination, frame.CGImage, (__bridge CFDictionaryRef)frameProperties);
        }
    }
    
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"failed to finalize image destination");
    }
    CFRelease(destination);
    
    completion(gifURL);
}


@end
