@protocol CDVHeartBeatDetectionDelegate

- (void)heartRateStart;
- (void)heartRateUpdate:(int)bpm atTime:(int)seconds bfi:(NSMutableArray*)bfi sbi:(NSMutableArray*)sdi hue:(NSMutableArray*)hue;
- (void)heartRateEnd;
- (void)heartRateError;

@end

@interface CDVHeartBeatDetection : NSObject

@property (nonatomic, weak) id<CDVHeartBeatDetectionDelegate> delegate;
@property (nonatomic, assign) int seconds;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) int camera;
@property (nonatomic, strong) NSMutableArray *returnArray;
@property (nonatomic, strong) NSMutableArray *dataPointsHue;
@property (nonatomic, assign) BOOL heartBeatError;
//@property (nonatomic, assign) int redThreshold;

- (void)startDetection;
- (void)stopDetection:(bool)error;
- (BOOL)hasCameraPermission;

@end
