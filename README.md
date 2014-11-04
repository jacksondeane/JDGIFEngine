JDGIFEngine
===========
An iOS class to generate animated GIFs from a video file.

``` objectivec
JDGIFEngine *gifEngine = [JDGIFEngine new];

JDGIFEngineOperation *operation;
operation = [gifEngine operationWithVideoURL:videoPath cropStartTime:0 cropEndTime:MAXFLOAT overlayImage:nil previewImage:^(UIImage *previewImage) {
    NSLog(@"previewImage: %@", previewImage);
} completion:^(NSURL *gifURL) {
    NSLog(@"gifURL: %@", gifURL);
}];

[gifEngine addOperationToQueue:operation];
```
