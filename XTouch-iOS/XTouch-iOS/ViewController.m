//
//  ViewController.m
//  XTouch-iOS
//
//  Created by Keng Kiat Lim on 24/1/15.
//  Copyright (c) 2015 XTouch. All rights reserved.
//

#import "ViewController.h"

#define RED_COLOR [UIColor redColor]

@interface ViewController () {
    AVCaptureVideoPreviewLayer *previewLayer;
    UIView *overlayView;
    UIView *topLeft;
    UIView *topRight;
    UIView *bottomLeft;
    UIView *bottomRight;
    NSMutableArray *vs;
    NSMutableArray *last;
}

@end

@implementation ViewController

- (NSArray *)detectRectangles:(CIImage *)image
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:CIDetectorAccuracyHigh, CIDetectorAccuracy, nil];
    CIDetector *rectDetector = [CIDetector detectorOfType:CIDetectorTypeRectangle context:nil options:options];

    NSArray *rectangles = [rectDetector featuresInImage:image];
    return rectangles;
}

- (UIBezierPath *)createPathFromRect:(CIRectangleFeature *)rect
{
    UIBezierPath *path = [UIBezierPath new];
    // Start at the first corner
    [path moveToPoint:rect.topLeft];
    [path addLineToPoint:rect.topRight];
    [path addLineToPoint:rect.bottomRight];
    [path addLineToPoint:rect.bottomLeft];
    [path addLineToPoint:rect.topLeft];
    
    return path;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    vs = [NSMutableArray new];
    topLeft = [UIView new];
    topRight = [UIView new];
    bottomLeft = [UIView new];
    bottomRight = [UIView new];
    
    [vs addObject:topLeft];
    [vs addObject:topRight];
    [vs addObject:bottomLeft];
    [vs addObject:bottomRight];
    
    last = [NSMutableArray new];
    CGPoint tl = CGPointMake(0,0);
    CGPoint tr = CGPointMake(0,0);
    CGPoint bl = CGPointMake(0,0);
    CGPoint br = CGPointMake(0,0);
    
    [last addObject:[NSValue valueWithCGPoint:tl]];
    [last addObject:[NSValue valueWithCGPoint:tr]];
    [last addObject:[NSValue valueWithCGPoint:bl]];
    [last addObject:[NSValue valueWithCGPoint:br]];


    // Do any additional setup after loading the view, typically from a nib.
    imageView.frame = self.view.frame;
    
    CGFloat videoHeight = 352.f/288.f * self.view.frame.size.width;
    CGFloat offsetTop = (self.view.frame.size.height - videoHeight) / 2;
    overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, offsetTop, self.view.frame.size.width, videoHeight)];
    [self.view addSubview:overlayView];
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset352x288;
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.frame = imageView.bounds;
    [imageView.layer addSublayer:previewLayer];

    NSError *error = nil;
    AVCaptureDevice *device = [self backCamera];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handle the error appropriately.
        NSLog(@"ERROR: trying to open camera: %@", error);
    }
    
    AVCaptureVideoDataOutput *videoDataOutput = [AVCaptureVideoDataOutput new];
    NSDictionary *newSettings =
    @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    videoDataOutput.videoSettings = newSettings;
    
    // discard if the data output queue is blocked (as we process the still image
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
    videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    
    if ( [session canAddOutput:videoDataOutput] )
        [session addOutput:videoDataOutput];
    
    [session addInput:input];
    [session startRunning];

    for (UIView *v in vs) {
        [overlayView addSubview:v];
        v.frame = CGRectMake(0, 0, 10, 10);
        v.backgroundColor = [UIColor redColor];
    }
    
    
    
    
    
    
}


- (AVCaptureDevice *)backCamera {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionBack) {
            return device;
        }
    }
    return nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    
    if(interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }
    
    // and so on for other orientations
    
    return ((interfaceOrientation == UIInterfaceOrientationLandscapeRight));
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    
    if (attachments) {
        CFRelease(attachments);
    }
    
    NSArray *rectangles = [self detectRectangles:ciImage];
    
    CGSize s = overlayView.frame.size;
    CGFloat sy = s.height/352;
    CGFloat sx = s.width/288;
    CGFloat bs = 0; CIRectangleFeature *bestr = nil;
    CGFloat rate = 0.4;
    
    for (CIRectangleFeature *rect in rectangles) {
        CGFloat ts = (rect.topRight.x - rect.topLeft.x) * (rect.topRight.y - rect.bottomRight.y);
        if (ts > bs) {
            bs = ts;
            bestr = rect;
        }
    }
    
    if (bs > 0) {
        topLeft.center = CGPointMake(bestr.topLeft.y * sy * rate + (1-rate) * [last[0] CGPointValue].x
                                     , bestr.topLeft.x * sx * rate + (1-rate) * [last[0] CGPointValue].y);
        topRight.center = CGPointMake(bestr.topRight.y * sy * rate + (1-rate) * [last[1] CGPointValue].x,
                                      bestr.topRight.x * sx * rate + (1-rate) * [last[1] CGPointValue].y);
        bottomRight.center = CGPointMake(bestr.bottomRight.y * sy * rate + (1-rate) * [last[2] CGPointValue].x,
                                         bestr.bottomRight.x * sx * rate + (1-rate) * [last[2] CGPointValue].y);
        bottomLeft.center = CGPointMake(bestr.bottomLeft.y * sy * rate + (1-rate) * [last[3] CGPointValue].x,
                                        bestr.bottomLeft.x * sx * rate + (1-rate) * [last[3] CGPointValue].y);
        [CATransaction flush];
        [last removeAllObjects];
        [last addObject:[NSValue valueWithCGPoint:CGPointMake(topLeft.center.x, topLeft.center.y)]];
        [last addObject:[NSValue valueWithCGPoint:CGPointMake(topRight.center.x, topRight.center.y)]];
        [last addObject:[NSValue valueWithCGPoint:CGPointMake(bottomRight.center.x, bottomRight.center.y)]];
        [last addObject:[NSValue valueWithCGPoint:CGPointMake(bottomLeft.center.x, bottomLeft.center.y)]];

    }
}

- (IBAction)handleGesture:(UIPanGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self.view];
    CGFloat translatedX = (point.x - topLeft.center.y) / (topRight.center.y - topLeft.center.y);
    CGFloat translatedY = (point.y - bottomLeft.center.x) / (topLeft.center.x - bottomLeft.center.x);
    
    NSLog(@"%f %f", translatedX, translatedY);
    if (translatedX < 0.0 || translatedX > 1.0 || translatedY < 0.0 || translatedY > 1.0) {
        return;
    }
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            break;
            
        case UIGestureRecognizerStateChanged:
            break;
        
        case UIGestureRecognizerStateEnded:
            break;
            
        default:
            break;
    }
}

- (void)logViewHierarchy:(UIView *)view
{
    NSLog(@"%@", self);
    for (UIView *subview in view.subviews) {
        [self logViewHierarchy: subview];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
