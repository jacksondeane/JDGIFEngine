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
        
        //Set up Image Generator
        NSTimeInterval normalizedEndTime = MIN(endTime, CMTimeGetSeconds([videoAsset duration]));
        NSTimeInterval cropDuration = normalizedEndTime - startTime;
        NSInteger snapshotCount = ceil(cropDuration * kFramesPerSecond);
        CGSize snapshotSize = CGSizeMake(480.0f, 640.0f);
        
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:videoAsset];
        imageGenerator.maximumSize = snapshotSize;
        imageGenerator.appliesPreferredTrackTransform = YES;
        imageGenerator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        
        
        //Set up GIF Creation; kCGImagePropertyGIFLoopCount = 0 = loop forever
        NSDictionary *fileProperties = @{(__bridge id)kCGImagePropertyGIFDictionary : @{(__bridge id)kCGImagePropertyGIFLoopCount: @0,}};
        
        CGFloat frameDuration = (100.0f / kFramesPerSecond) / 100.0f;
        NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary : @{(__bridge id)kCGImagePropertyGIFDelayTime : @(frameDuration)}};
        
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        NSURL *gifURL = [documentsDirectoryURL URLByAppendingPathComponent:@"output.gif"];
        
        //Write GIF to the specified URL:
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, snapshotCount, NULL);
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)fileProperties);
        
        BOOL sentPreview = NO;
        for (NSInteger snapshotIndex = 0; snapshotIndex < snapshotCount; snapshotIndex++) {
            CMTime time = CMTimeMakeWithSeconds(((cropDuration / snapshotCount) * snapshotIndex) + startTime, 1000);
            
            if (![operation isCancelled]) {
                NSError *error;
                UIImage *image = [UIImage imageWithCGImage:[imageGenerator copyCGImageAtTime:time actualTime:nil error:&error]];
                image = [JDGIFEngine scaleAndCropImage:image resolution:320/384 maxSize:CGSizeMake(320, 384)];
                
                if (overlayImage) {
                    image = [JDGIFEngine imageByCombiningImage:image withImage:overlayImage]; //add overlay
                }
                
                //Add to GIF
                @autoreleasepool {
                    CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)frameProperties);
                }
                
                if (!sentPreview) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        operation.previewImageBlock(image);
                    }];
                    sentPreview = YES;
                }
                
                
                if (snapshotIndex >= snapshotCount) {
                    break;
                }
            } else {
                NSLog(@"operation canceled: %@", operation);
                return;
            }
        }
        
        //Make the GIF
        if (![operation isCancelled]) {
            if (!CGImageDestinationFinalize(destination)) {
                NSLog(@"failed to finalize image destination");
            }
            CFRelease(destination);
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                operation.completionBlock(gifURL);
            }];
            
        } else {
            NSLog(@"operation canceled: %@", operation);
            return;
        }
        
    }];
    
    operation.previewImageBlock = previewImage;
    operation.completionBlock = completion;
    
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
    //NSLog(@"imageByCombiningImage: [%f x %f]  & [%f x %f]", firstImage.size.width, firstImage.size.height, secondImage.size.width, secondImage.size.height);
    
    UIImage *image;
    
    //hardcoded to respect 1st images size
    CGFloat scale = secondImage.scale * secondImage.size.height / firstImage.size.height;
    secondImage = [UIImage imageWithCGImage:[secondImage CGImage] scale:scale orientation:(secondImage.imageOrientation)];
    
    //CGSize newImageSize = CGSizeMake(MAX(firstImage.size.width, secondImage.size.width), MAX(firstImage.size.height, secondImage.size.height));
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
    //NSLog(@"%f x %f", image.size.width, image.size.height);
    return image;
}

+ (UIImage*)scaleAndCropImage:(UIImage*)image resolution:(CGFloat)resolution maxSize:(CGSize)maxSize {
    
    //Scale Image
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
    
    //Cleanup
    CGImageRelease(croppedImageRef);
    
    //NSLog(@"scaleAndCropImage: sourceImage:%@ newImage.size:%@", NSStringFromCGSize(image.size), NSStringFromCGSize(newImage.size));
    
    return newImage;
}

@end


@implementation JDGIFEngineOperation

@end