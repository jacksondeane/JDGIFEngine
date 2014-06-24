//
//  JDGIFEngine.h
//  JDGIFEngineDemo
//
//  Created by Jackson Deane on 6/24/14.
//  Copyright (c) 2014 Jackson Deane. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JDGIFEngine : NSObject

@property (nonatomic, assign) CGFloat framesPerSecond;
@property (nonatomic, assign) CGSize maximumSize;

- (void)generateGIFForVideoPath:(NSURL*)videoPath completion:(void (^)(NSURL *gifURL))completion;
- (void)generateGIFForVideoPath:(NSURL*)videoPath startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime completion:(void (^)(NSURL *gifURL))completion;

@end
