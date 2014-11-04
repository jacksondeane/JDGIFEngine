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


static NSUInteger const kFramesPerSecond = 10;

@interface JDGIFEngine()
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end


@implementation JDGIFEngine

- (id)init {
    self = [super init];
    if (self != nil) {
        self.operationQueue = [NSOperationQueue new];
    }
    return self;
}


#pragma mark Public


- (JDGIFEngineOperation*)operationWithVideoURL:(NSURL*)videoURL cropStartTime:(NSTimeInterval)cropStartTime cropEndTime:(NSTimeInterval)cropEndTime overlayImage:(UIImage*)overlayImage previewImage:(void (^)(UIImage *previewImage))previewImage completion:(void (^)(NSURL *gifURL))completion {
    
    __block JDGIFEngineOperation *operation = [JDGIFEngineOperation blockOperationWithBlock:^{
        
        AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
        NSTimeInterval startTime = cropStartTime;
        NSTimeInterval endTime = cropEndTime;
        NSTimeInterval duration = CMTimeGetSeconds([videoAsset duration]);
        
        NSTimeInterval normalizedEndTime = MIN(endTime, duration);
        NSTimeInterval cropDuration = normalizedEndTime - startTime;
        NSInteger snapshotCount = ceil(cropDuration * kFramesPerSecond);
        CGSize snapshotSize = CGSizeMake(480.0f, 640.0f);
        
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:videoAsset];
        imageGenerator.maximumSize = snapshotSize;
        imageGenerator.appliesPreferredTrackTransform = YES;
        imageGenerator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        
        NSMutableArray *frames = [NSMutableArray new];
        BOOL sentPreview = NO;
        for (NSInteger snapshotIndex = 0; snapshotIndex < snapshotCount; snapshotIndex++) {
            CMTime time = CMTimeMakeWithSeconds(((cropDuration / snapshotCount) * snapshotIndex) + startTime, 1000);
            
            if (![operation isCancelled]) {
                NSError *error;
                UIImage *image = [UIImage imageWithCGImage:[imageGenerator copyCGImageAtTime:time actualTime:NULL error:&error]];
                if (error) {
                    NSLog(@"Error getting image at time %f: %@", CMTimeGetSeconds(time), error);
                    continue;
                }
                
                image = [JDGIFEngine scaleAndCropImage:image resolution:320/384 maxSize:CGSizeMake(320, 384)];
                
                if (overlayImage) {
                    image = [JDGIFEngine imageByCombiningImage:image withImage:overlayImage]; //add overlay
                }
                [frames addObject:image];
                
                if (!sentPreview) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        operation.previewImageBlock(image);
                    }];
                    sentPreview = YES;
                }
            } else {
                NSLog(@"operation canceled: %@", operation);
                return;
            }
        }
        
        //MAKE GIF
        if (![operation isCancelled]) {
            CGFloat frameDuration = (100.0f / kFramesPerSecond) / 100.0f;
            NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary : @{(__bridge id)kCGImagePropertyGIFDelayTime : @(frameDuration)}};
            
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
            NSURL *gifURL = [documentsDirectoryURL URLByAppendingPathComponent:@"output.gif"];
            
            CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, [frames count], NULL);
            
            for (UIImage *frame in frames) {
                @autoreleasepool {
                    CGImageDestinationAddImage(destination, frame.CGImage, (__bridge CFDictionaryRef)frameProperties);
                }
            }
            
            NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary : @{(__bridge id)kCGImagePropertyGIFLoopCount: @0,}};
            CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
            if (!CGImageDestinationFinalize(destination)) {
                NSLog(@"failed to finalize image destination");
            }
            CFRelease(destination);
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                operation.finishedBlock(gifURL);
            }];
            
        } else {
            NSLog(@"operation canceled: %@", operation);
            return;
        }
        
    }];
    
    operation.previewImageBlock = previewImage;
    operation.finishedBlock = completion;
    
    return operation;
}

- (JDGIFEngineOperation*)operationWithFrames:(NSArray*)frames frameDuration:(NSTimeInterval)frameDuration previewImage:(void (^)(UIImage *previewImage))previewImage completion:(void (^)(NSURL *gifURL))completion {
    __block JDGIFEngineOperation *operation = [JDGIFEngineOperation blockOperationWithBlock:^{
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            operation.previewImageBlock([frames firstObject]); //Preview hardcoded to 1st frame
        }];
        
        
        if (![operation isCancelled]) {
            //CGFloat frameDuration = (100.0f / kFramesPerSecond) / 100.0f;
            NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary : @{(__bridge id)kCGImagePropertyGIFDelayTime : @(frameDuration)}};
            
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
            NSURL *gifURL = [documentsDirectoryURL URLByAppendingPathComponent:@"output.gif"];
            
            CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, [frames count], NULL);
            
            BOOL sentPreview = NO;
            for (__strong UIImage *frame in frames) {
                frame = [JDGIFEngine scaleAndCropImage:frame resolution:320/384 maxSize:CGSizeMake(320, 384)];
                
                if (!sentPreview) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        operation.previewImageBlock(frame);
                    }];
                    sentPreview = YES;
                }
                
                @autoreleasepool {
                    CGImageDestinationAddImage(destination, frame.CGImage, (__bridge CFDictionaryRef)frameProperties);
                }
            }
            
            NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary : @{(__bridge id)kCGImagePropertyGIFLoopCount: @0,}};
            CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
            if (!CGImageDestinationFinalize(destination)) {
                NSLog(@"failed to finalize image destination");
            }
            CFRelease(destination);
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                operation.finishedBlock(gifURL);
            }];
            
        } else {
            NSLog(@"operation canceled: %@", operation);
            return;
        }
        
    }];
    
    operation.previewImageBlock = previewImage;
    operation.finishedBlock = completion;
    
    return operation;

    }

- (void)addOperationToQueue:(JDGIFEngineOperation*)operation {
    [self.operationQueue addOperation:operation];
}

- (void)cancelAllOperations {
    [self.operationQueue cancelAllOperations];
}


#pragma mark Private

+ (UIImage*)imageByCombiningImage:(UIImage*)firstImage withImage:(UIImage*)secondImage {
    UIImage *image;
    
    //hardcoded to respect 1st images size
    CGFloat scale = secondImage.scale * secondImage.size.height / firstImage.size.height;
    secondImage = [UIImage imageWithCGImage:[secondImage CGImage] scale:scale orientation:(secondImage.imageOrientation)];
    
    CGSize newImageSize = firstImage.size; //force 1st image size
    
    if (UIGraphicsBeginImageContextWithOptions != NULL) {
        UIGraphicsBeginImageContextWithOptions(newImageSize, NO, 1.0f);
    } else {
        UIGraphicsBeginImageContext(newImageSize);
    }
    [firstImage drawAtPoint:CGPointMake(roundf((newImageSize.width-firstImage.size.width)/2),
                                        roundf((newImageSize.height-firstImage.size.height)/2))];
    [secondImage drawAtPoint:CGPointMake(roundf((newImageSize.width-secondImage.size.width)/2),
                                         roundf((newImageSize.height-secondImage.size.height)/2))];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage*)scaleAndCropImage:(UIImage*)image resolution:(CGFloat)resolution maxSize:(CGSize)maxSize {
    
    CGFloat widthScaleFactor = maxSize.width / image.size.width;
    CGFloat heightScaleFactor = maxSize.height / image.size.height;
    CGFloat scaleFactor = (widthScaleFactor > heightScaleFactor) ? widthScaleFactor : heightScaleFactor;
    
    CGSize scaledSize = CGSizeMake(image.size.width * scaleFactor, image.size.height * scaleFactor);

    UIGraphicsBeginImageContext(scaledSize);
    [image drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //Crop Image
    CGFloat widthToChop = scaledSize.width - maxSize.width; //ex: 320 - 320 = 0
    CGFloat heightToChop = scaledSize.height - maxSize.height; //ex: 427 - 384 = 43
    
    CGFloat xOffset = widthToChop / 2;
    CGFloat yOffset = heightToChop / 2;
    CGRect cropRect = CGRectMake(xOffset, yOffset, (scaledImage.size.width-widthToChop), (scaledImage.size.height-heightToChop));
    
    //Create the cropped image
    CGImageRef croppedImageRef = CGImageCreateWithImageInRect(scaledImage.CGImage, cropRect);
    UIImage *newImage = [UIImage imageWithCGImage:croppedImageRef scale:image.scale orientation:image.imageOrientation];
    
    CGImageRelease(croppedImageRef);
    
    
    return newImage;
}


@end


@interface JDGIFEngineOperation ()
@end

@implementation JDGIFEngineOperation

@end