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
        //NSLog(@"snapshotImage: %@ (scale: %f)",NSStringFromCGSize(snapshotImage.size), snapshotImage.scale);
        [frames addObject:snapshotImage];
    } completion:^{
        [self generateGIFWithFrames:frames duration:videoDuration completion:^(NSURL *gifURL) {
            
            NSError *error;
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[gifURL relativePath] error:&error];
            NSString *kbString = [NSByteCountFormatter stringFromByteCount:[fileAttributes fileSize] countStyle:NSByteCountFormatterCountStyleBinary];
            NSLog(@"gifURL: %@ [%@]", gifURL, kbString);
            
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
        
        
        //CGSize naturalSize = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
        //CGFloat scaleFactor = kSPGIFEngineWidth / naturalSize.width;
        //CGSize snapshotSize = CGSizeMake(naturalSize.width * scaleFactor, naturalSize.height * scaleFactor);
        
        //NSLog(@"naturalSize: %@  snapshotSize: %@  scaleFactor: %f", NSStringFromCGSize(naturalSize), NSStringFromCGSize(snapshotSize), scaleFactor);
        NSMutableArray *times = [NSMutableArray array];
        for (NSInteger snapshotIndex = 0; snapshotIndex < snapshotCount; snapshotIndex++) {
            CMTime time = CMTimeMakeWithSeconds(((videoDuration / snapshotCount) * snapshotIndex) + startTime, 1000);
            [times addObject:[NSValue valueWithCMTime:time]];
        }
        
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        __block NSInteger snapshotIndex = 0;
        
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        
        //imageGenerator.maximumSize = snapshotSize;
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
    
    //We'll need a property dictionary to specify the number of times the animation should repeat:
    //kCGImagePropertyGIFLoopCount = 0 = loop forever
    NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
                                         @{(__bridge id)kCGImagePropertyGIFLoopCount: @0, }
                                     };
    
    //And we'll need another property dictionary, which we'll attach to each frame, specifying how long that frame should be displayed:
    //kCGImagePropertyGIFDelayTime= a float (not double!) in seconds, rounded to centiseconds in the GIF data
    //.02 is min for browsers
    #warning  I dont think this is right
    CGFloat frameDuration = (100.0f / self.framesPerSecond) / 100.0f;
    NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary :
                                          @{(__bridge id)kCGImagePropertyGIFDelayTime : @(frameDuration)}
                                      };
    //We'll also create a URL for the GIF in our documents directory:
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *gifURL = [documentsDirectoryURL URLByAppendingPathComponent:@"output.gif"];
    
    //Now we can create a CGImageDestination that writes a GIF to the specified URL:
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, [frames count], NULL);
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
    
    //write frames
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
