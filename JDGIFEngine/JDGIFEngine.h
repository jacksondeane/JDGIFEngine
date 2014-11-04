//
//  JDGIFEngine.h
//  JDGIFEngineDemo
//
//  Created by Jackson Deane on 6/24/14.
//  Copyright (c) 2014 Jackson Deane. All rights reserved.
//

#import <Foundation/Foundation.h>
@class JDGIFEngineOperation;

@interface JDGIFEngine : NSObject

- (JDGIFEngineOperation*)operationWithVideoURL:(NSURL*)videoURL cropStartTime:(NSTimeInterval)cropStartTime cropEndTime:(NSTimeInterval)cropEndTime overlayImage:(UIImage*)overlayImage previewImage:(void (^)(UIImage *previewImage))previewImage completion:(void (^)(NSURL *gifURL))completion;
- (void)addOperationToQueue:(JDGIFEngineOperation*)operation;
- (void)cancelAllOperations;

@end


typedef void(^previewImage)(UIImage*);
typedef void(^finished)(NSURL*);

@interface JDGIFEngineOperation : NSBlockOperation
@property (copy) previewImage previewImageBlock;
@property (copy) finished finishedBlock;
@end