#import "CDVHeartBeatDetection.h"
#import <AVFoundation/AVFoundation.h>

@interface CDVHeartBeatDetection() <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
//@property (nonatomic, strong) NSMutableArray *dataPointsHue;
//@property (nonatomic, strong) NSMutableArray *returnArray;
@end

@implementation CDVHeartBeatDetection

int failedFrames;

#pragma mark - Data collection

/* start the measurement and calculation */
- (void)startDetection
{
    self.returnArray = [[NSMutableArray alloc] init];
    self.dataPointsHue = [[NSMutableArray alloc] init];
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetLow;
    failedFrames = 0;

    //AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDualCamera,AVCaptureDeviceTypeBuiltInUltraWideCamera,AVCaptureDeviceTypeBuiltInTelephotoCamera]
    //AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
    //                                      mediaType:AVMediaTypeVideo
    //                                       position:AVCaptureDevicePositionBack];

    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession;
    if (self.camera == 0){
        captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                          mediaType:AVMediaTypeVideo
                                           position:AVCaptureDevicePositionBack];
    }

    else if (self.camera == 1 ){
        captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInDualCamera]
                                          mediaType:AVMediaTypeVideo
                                           position:AVCaptureDevicePositionBack];
    }

    else if (self.camera == 2){
        captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInUltraWideCamera]
                                          mediaType:AVMediaTypeVideo
                                           position:AVCaptureDevicePositionBack];
    }

    else if (self.camera == 3){
        captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTelephotoCamera]
                                          mediaType:AVMediaTypeVideo
                                           position:AVCaptureDevicePositionBack];
    }

    NSArray *captureDevices = [captureDeviceDiscoverySession devices];
    
    AVCaptureDevice *captureDevice;
    for (AVCaptureDevice *device in captureDevices)
    {
        if ([device hasMediaType:AVMediaTypeVideo])
        {
            if (device.position == AVCaptureDevicePositionBack)
            {
                captureDevice = device;
                break;
            }
        }
    }
    
    // Add the device to capture the Video Input to the session
    NSError *error;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if ([self.session canAddInput:input])
    {
        [self.session addInput:input];
    }
    
    if (error)
    {
        NSLog(@"%@", error);
        self.heartBeatError = true;
    }

    // Set the format of the video.
    AVCaptureDeviceFormat *currentFormat;
    for (AVCaptureDeviceFormat *format in captureDevice.formats)
    {
        NSArray *ranges = format.videoSupportedFrameRateRanges;
        AVFrameRateRange *frameRates = ranges[0];
        
        if (frameRates.maxFrameRate == self.fps && (!currentFormat || (CMVideoFormatDescriptionGetDimensions(format.formatDescription).width < CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription).width && CMVideoFormatDescriptionGetDimensions(format.formatDescription).height < CMVideoFormatDescriptionGetDimensions(currentFormat.formatDescription).height)))
        {
            currentFormat = format;
        }
    }
    
    // Configure the camera settings
    [captureDevice lockForConfiguration:nil];
    /* Flash/Torch can't be turned on before the camera is running.
     * captureDevice.torchMode=AVCaptureTorchModeOn;
     */

    // Assign the format that is set in the previous step.
    captureDevice.activeFormat = currentFormat;
    
    // The fixed framerate is needed to calculate the time running based on frames.
    captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, self.fps);
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, self.fps);
    [captureDevice unlockForConfiguration];
    
    // Set the output video that is needed to calculate the heartrate.
    AVCaptureVideoDataOutput* videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    // Create a queue of frames that are captured.
    dispatch_queue_t captureQueue=dispatch_queue_create("captureQueue", NULL);
    
    // Configure the output settings.
    [videoOutput setSampleBufferDelegate:self queue:captureQueue];
    videoOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA], (id)kCVPixelBufferPixelFormatTypeKey,
                                 nil];
    videoOutput.alwaysDiscardsLateVideoFrames = NO;
    [self.session addOutput:videoOutput];
    
    // Start the camera
    [self.session startRunning];
    
    // Turn on the flash and/or torch - Turning on both instead of only the torch saves battery-consumption
    //AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *device = captureDevice;
    if ([device hasFlash]){
        [device lockForConfiguration:nil];
        [device setFlashMode:AVCaptureFlashModeOn];
        [device unlockForConfiguration];
    }

    if ([device hasTorch]){
        [device lockForConfiguration:nil];
        [device setTorchMode:AVCaptureTorchModeOn];
        [device unlockForConfiguration];
    }

    if (self.delegate)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate heartRateStart];
        });
    }
}

- (BOOL) hasCameraPermission {
    // Validate the app has permission to access the camera
    __block BOOL hasPermission = false;
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if(!granted) {
            hasPermission = false;
        } else {
            hasPermission = true;
        }
    }];
    return hasPermission;
}

- (void)stopDetection:(bool)error
{
    [self.session stopRunning];
    count = 0;
    failedFrames = 0;
//    [self.returnArray removeAllObjects];
    
    // Turn off the flash and/or torch
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasFlash]){
        [device lockForConfiguration:nil];
        [device setFlashMode:AVCaptureFlashModeOff];
        [device unlockForConfiguration];
    }

    if ([device hasTorch]){
        [device lockForConfiguration:nil];
        [device setTorchMode:AVCaptureTorchModeOff];
        [device unlockForConfiguration];
    }
    if (self.delegate){
        if(error == true) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.heartBeatError = true;
                [self.delegate heartRateError];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate heartRateEnd];
            });
        }
    }
}

int decodeYUV420SPtoRedSum(Byte yuv420sp[], float width, float height) {
    if (yuv420sp == nil) return 0;
    int frameSize = width * height;
    int sum = 0;
    for (int j = 0, yp = 0; j < height; j++) {
        int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
        for (int i = 0; i < width; i++, yp++) {
            int y = (0xff & yuv420sp[yp]) - 16;
            if (y < 0) y = 0;
            if ((i & 1) == 0) {
                v = (0xff & yuv420sp[uvp++]) - 128;
                u = (0xff & yuv420sp[uvp++]) - 128;
            }
            int y1192 = 1192 * y;
            int r = (y1192 + 1634 * v);
            int g = (y1192 - 833 * v - 400 * u);
            int b = (y1192 + 2066 * u);
            if (r < 0) r = 0;
            else if (r > 262143) r = 262143;
            if (g < 0) g = 0;
            else if (g > 262143) g = 262143;
            if (b < 0) b = 0;
            else if (b > 262143) b = 262143;
            int pixel = 0xff000000 | ((r << 6) & 0xff0000) | ((g >> 2) & 0xff00) | ((b >> 10) & 0xff);
            int red = (pixel >> 16) & 0xff;
            sum += red;
        }
    }
    return sum;
}


/*Given a byte array representing a yuv420sp image, determine the average
 *amount of red in the image. Note: returns 0 if the byte array is NULL.
 *@param yuv420sp Byte array representing a yuv420sp image
 *@param width    Width of the image.
 *@param height   Height of the image.
 *@return int representing the average amount of red in the image.
*/
int decodeYUV420SPtoRedAvg(Byte yuv420sp[], float width, float height) {
    if (yuv420sp == nil) return 0;
    int frameSize = width * height;
    int sum = decodeYUV420SPtoRedSum (yuv420sp, width, height);
    return (sum / frameSize);
}

static int count=0;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    count++;
    
    CVImageBufferRef cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(cvimgRef,0);
    NSInteger width = CVPixelBufferGetWidth(cvimgRef);
    NSInteger height = CVPixelBufferGetHeight(cvimgRef);
    
    uint8_t *buf=(uint8_t *) CVPixelBufferGetBaseAddress(cvimgRef);
    size_t bprow=CVPixelBufferGetBytesPerRow(cvimgRef);
    float r=0,g=0,b=0;
    
    /*long widthScaleFactor = width/192;
    long heightScaleFactor = height/144;*/
    long widthScaleFactor = [UIScreen mainScreen].scale;
    long heightScaleFactor = [UIScreen mainScreen].scale;;
    
    /*long widthScaleFactor = width;
    long heightScaleFactor = height;*/
    
    int value = decodeYUV420SPtoRedAvg(buf, width, height);
//    NSLog(@">>> %i", value);
    
    for(int y=0; y < height; y+=heightScaleFactor) {
        for(int x=0; x < width*4; x+=(4*widthScaleFactor)) {
            b+=buf[x];
            g+=buf[x+1];
            r+=buf[x+2];
        }
        buf+=bprow;
    }
//    NSLog(@"1>>>R:%f, G:%f, B:%f", r, g, b);
    float hue, sat, bright;
    RGBtoHSV(r, g, b, &hue, &sat, &bright);
    //[color getHue:&hue saturation:&sat brightness:&bright alpha:nil];

    r/=255*(float) (width*height/widthScaleFactor/heightScaleFactor);
    g/=255*(float) (width*height/widthScaleFactor/heightScaleFactor);
    b/=255*(float) (width*height/widthScaleFactor/heightScaleFactor);

    //Need to redo the sum and if
//    UIColor *color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
//    NSLog(@">>>R:%f, G:%f, B:%f", r*255, g*255, b*255);
    int redness = [self getRednessR:r*255 G:g*255 B:b*255];
    NSLog(@"Redness & count: %d, %i // ", redness, count);
    
    if(redness < 40){
        failedFrames +=1;
        if (failedFrames > 20) {
            [self stopDetection: true];
                return;
        }
    }
    
    if (count > 5 || (count > 5 && count < self.fps * self.seconds -3 )) {
        // Criar Dictionary com todos os redness e rgb e devolvo isso no result do Cordova
        float red = r*255;
        float green = g*255;
        float blue = b*255;
        NSDictionary *resultsDict = @{ @"r" : [NSNumber numberWithFloat:red], @"g" : [NSNumber numberWithFloat:green], @"b" : [NSNumber numberWithFloat:blue], @"redness" : [NSNumber numberWithInt:redness]};
        
        [self.returnArray addObject:resultsDict];
    }
    
    if (count == self.fps * self.seconds -3) {
        [self stopDetection:false];
    }
    
//    if (!isnan(hue) && count > 10){
//          [self.dataPointsHue addObject:@(hue)];
//    }
    
    [self.dataPointsHue addObject:@(hue)];
    
    if (self.dataPointsHue.count == (self.fps * self.seconds) - 4)
    {
        if (self.delegate)
        {
            float displaySeconds = self.dataPointsHue.count / self.fps;
            
            NSMutableArray *bandpassFilteredItems = (NSMutableArray*) butterworthBandpassFilter(self.dataPointsHue);
            NSMutableArray *smoothedBandpassItems = (NSMutableArray*) medianSmoothing(bandpassFilteredItems);
            int peak = medianPeak(smoothedBandpassItems);
            int heartRate = 60 * self.fps / peak;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate heartRateUpdate:heartRate atTime:displaySeconds bfi:bandpassFilteredItems sbi:smoothedBandpassItems hue:self.dataPointsHue];
            });
        
        }
    }
    
    CVPixelBufferUnlockBaseAddress(cvimgRef,0);
    
    if (self.dataPointsHue.count == (self.seconds * self.fps))
    {
        [self stopDetection:false];
    }
    
}

- (int)getRednessR:(int)r G:(int)g B:(int)b {
    if (r > 150) {
        if ((r - g >= 60) && (r - b >= 60)) {
            if ((g - b < 60) && (b - g < 60)) {
                int redness = r - (g + b)/2;
                return redness;
            }
        }
    }
    return -1;
}

void RGBtoHSV( float r, float g, float b, float *h, float *s, float *v ) {
    float min, max, delta;
    min = MIN( r, MIN(g, b ));
    max = MAX( r, MAX(g, b ));
    *v = max;
    delta = max - min;
    if( max != 0 )
        *s = delta / max;
    else {
        *s = 0;
        *h = -1;
        return;
    }
    if( r == max )
        *h = ( g - b ) / delta;
    else if( g == max )
        *h=2+(b-r)/delta;
    else
        *h=4+(r-g)/delta;
    *h *= 60;
    if( *h < 0 )
        *h += 360;
}

#pragma mark - Data processing

// http://www-users.cs.york.ac.uk/~fisher/cgi-bin/mkfscript
// Butterworth Bandpass filter
NSArray * butterworthBandpassFilter(NSArray *inputData)
{
    const int NZEROS = 8;
    const int NPOLES = 8;
    static float xv[NZEROS+1], yv[NPOLES+1];
    
    double dGain = 1.232232910e+02;
    
    NSMutableArray *outputData = [[NSMutableArray alloc] init];
    for (NSNumber *number in inputData)
    {
        double input = number.doubleValue;
        
        xv[0] = xv[1];
        xv[1] = xv[2];
        xv[2] = xv[3];
        xv[3] = xv[4];
        xv[4] = xv[5];
        xv[5] = xv[6];
        xv[6] = xv[7];
        xv[7] = xv[8];
        xv[8] = input / dGain;
        yv[0] = yv[1];
        yv[1] = yv[2];
        yv[2] = yv[3];
        yv[3] = yv[4];
        yv[4] = yv[5];
        yv[5] = yv[6];
        yv[6] = yv[7];
        yv[7] = yv[8];
        yv[8] = (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4]
        + ( -0.1397436053 * yv[0]) + (  1.2948188815 * yv[1])
        + ( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3])
        + (-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5])
        + (-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7]);
        
        [outputData addObject:@(yv[8])];
    }
    
    return outputData;
}

int medianPeak(NSArray *inputData)
{
    NSMutableArray *peaks = [[NSMutableArray alloc] init];
    int count = 4;
    for (int i = 3; i < inputData.count - 3; i++,count++)
    {
        if (inputData[i] > 0 &&
            [inputData[i] floatValue] > [inputData[i-1] floatValue] &&
            [inputData[i] floatValue] > [inputData[i-2] floatValue] &&
            [inputData[i] floatValue] > [inputData[i-3] floatValue] &&
            [inputData[i] floatValue] >= [inputData[i+1] floatValue] &&
            [inputData[i] floatValue] >= [inputData[i+2] floatValue] &&
            [inputData[i] floatValue] >= [inputData[i+3] floatValue]
            )
        {
            [peaks addObject:@(count)];
            i += 3;
            count = 3;
        }
    }
    [peaks setObject:@([peaks[0] integerValue] + count + 3) atIndexedSubscript: 0];
    [peaks sortUsingComparator:^(NSNumber *a, NSNumber *b){
        return [a compare:b];
    }];
    int medianPeak = (int)[peaks[peaks.count * 2 / 3] integerValue];
    return medianPeak;
}

NSArray *medianSmoothing(NSArray *inputData)
{
    NSMutableArray *newData = [[NSMutableArray alloc] init];
    for (int i = 0; i < inputData.count; i++)
    {
        if (i == 0 ||
            i == 1 ||
            i == 2 ||
            i == inputData.count - 1 ||
            i == inputData.count - 2 ||
            i == inputData.count - 3)        {
            [newData addObject:inputData[i]];
        }
        else
        {
            NSArray *items = [@[
                                inputData[i-2],
                                inputData[i-1],
                                inputData[i],
                                inputData[i+1],
                                inputData[i+2],
                                ] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];

            [newData addObject:items[2]];
        }
    }
    
    return newData;
}

@end
