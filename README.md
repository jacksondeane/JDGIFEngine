JDGIFEngine
===========
An iOS class to generate animated GIFs from a video file.

``` objectivec
JDGIFEngine *gifEngine = [JDGIFEngine new];
JDGIFEngineOperation *operation;

//GIF from video
operation = [gifEngine operationWithVideoURL:videoPath cropStartTime:0 cropEndTime:MAXFLOAT overlayImage:nil previewImage:^(UIImage *previewImage) {
    NSLog(@"previewImage: %@", previewImage);
} completion:^(NSURL *gifURL) {
    NSLog(@"gifURL: %@", gifURL);
}];

//GIF from still images
NSMutableArray *frames; //provide an array of UIImages
operation = [gifEngine operationWithFrames:frames frameDuration:.5 previewImage:^(UIImage *previewImage) {
    NSLog(@"previewImage: %@", previewImage);
} completion:^(NSURL *gifURL) {
    NSLog(@"gifURL: %@", gifURL);
}];

[gifEngine addOperationToQueue:operation];
```
