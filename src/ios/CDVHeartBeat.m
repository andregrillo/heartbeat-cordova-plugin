#import "CDVHeartBeat.h"
#import "CDVHeartBeatDetection.h"
#import <sys/sysctl.h>
#import <AVFoundation/AVFoundation.h>

@interface CDVHeartBeat()<CDVHeartBeatDetectionDelegate>

@property (nonatomic, assign) bool detecting;
@property (nonatomic, strong) NSMutableArray *bpms;
@property (nonatomic, strong) NSMutableArray *bfi;
@property (nonatomic, strong) NSMutableArray *sbi;
@property (nonatomic, strong) NSMutableArray *hue;
@property (nonatomic, assign) bool error;

@end

@implementation CDVHeartBeat


- (void)take:(CDVInvokedUrlCommand*)command{
    [self.commandDelegate runInBackground: ^{
        
        NSString* callbackId = [command callbackId];
        NSArray* arguments = command.arguments;
        
        CDVHeartBeatDetection* heartBeatDetection = [[CDVHeartBeatDetection alloc] init];
        heartBeatDetection.delegate = self;
        heartBeatDetection.seconds = [[arguments objectAtIndex:0] intValue];
        heartBeatDetection.fps = [[arguments objectAtIndex:1] intValue];
        //heartBeatDetection.redThreshold = [[arguments objectAtIndex:2] intValue];
        self.detecting = true;
        self.error = false;
        
        
//        if (!heartBeatDetection.hasCameraPermission) {
        if (![self checkCameraAuthorization]) {
            // Denied; show an alert
            __weak CDVHeartBeat* weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] message:NSLocalizedString(@"Access to the camera has been denied. Please enable it in the Settings app to continue.", nil) preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [weakSelf sendNoPermissionResult:command.callbackId];
                }]];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                    //[weakSelf sendNoPermissionResult:command.callbackId];
                }]];
                [weakSelf.viewController presentViewController:alertController animated:YES completion:nil];
            });
        } else {
            [heartBeatDetection startDetection];
            
            while(self.detecting){
                
            }
            
            NSError *error;
            if(heartBeatDetection.heartBeatError == false && heartBeatDetection.returnArray.count > 0 && heartBeatDetection.returnArray) {
                
                [self.bpms sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
                NSMutableArray *finalResult = [[NSMutableArray alloc] init ];
                if(self.error == false) {
                    int bpm = [((NSNumber*)self.bpms[self.bpms.count/2]) intValue];
                    NSMutableDictionary *jsonObj = [[NSMutableDictionary alloc]initWithCapacity:4];
                    [jsonObj setObject:[NSNumber numberWithInt:bpm] forKey:@"bpm"];
//                    [jsonObj setObject:[NSMutableArray arrayWithArray:self.bfi] forKey:@"bfi"];
//                    [jsonObj setObject:[NSMutableArray arrayWithArray:self.sbi] forKey:@"sbi"];
//                    [jsonObj setObject:[NSMutableArray arrayWithArray:self.hue] forKey:@"hue"];

                    [finalResult addObject:jsonObj];
                    [finalResult addObject:heartBeatDetection.returnArray];
                    
                }
                
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:finalResult
                                                                   options:NSJSONWritingPrettyPrinted
                                                                     error:&error];
                NSString *jsonString = @"";
                if (! jsonData) {
                    NSLog(@"Got an error converting to json: %@", error);
                } else {
                    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                }
                
                if ([jsonString isEqual:@""] || [jsonString isEqual:nil]) {
                    CDVPluginResult* resulterror = [CDVPluginResult
                                                    resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:@"Error converting NSDictionary to json format"];
                    [self.commandDelegate sendPluginResult:resulterror callbackId:callbackId];
                } else {
                    CDVPluginResult* result = [CDVPluginResult
                                               resultWithStatus:(CDVCommandStatus_OK)
                                               messageAsString:jsonString];
                    
                    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
                }
                
            } else {
                CDVPluginResult* resulterror = [CDVPluginResult
                                                resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsString:@"Error detecting heartbeat"];
                [self.commandDelegate sendPluginResult:resulterror callbackId:callbackId];
            }
        }
        
        
    }];
}

-(BOOL) checkCameraAuthorization {
    
//    NSString *mediaType = ;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authStatus == AVAuthorizationStatusAuthorized) {
        return true;
//    } else if(authStatus == AVAuthorizationStatusDenied){
//        return false;
//    } else if(authStatus == AVAuthorizationStatusRestricted){
//        return false;
//    } else if(authStatus == AVAuthorizationStatusNotDetermined){
//      // not determined?!
//        __block BOOL access;
//        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
//            if(granted){
//                access = true;
//            } else {
//                access = false;
//            }
//        }];
//        return access;
    } else {
      // impossible, unknown authorization status
        return false;
    }
}

- (void)sendNoPermissionResult:(NSString*)callbackId
{
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"has no access to camera"];

    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void)heartRateStart{
    self.bpms = [[NSMutableArray alloc] init];
}

- (void)heartRateUpdate:(int)bpm atTime:(int)seconds bfi:(NSMutableArray *)bfi sbi:(NSMutableArray *)sbi hue:(NSMutableArray *)hue {
    [self.bpms addObject:[NSNumber numberWithInt:bpm]];
    self.bfi = bfi;
    self.sbi = sbi;
    self.hue = hue;
}

- (void)heartRateEnd{
    self.detecting = false;
}

- (void)heartRateError{
    self.detecting = false;
    self.error = true;
}

- (void)getModel:(CDVInvokedUrlCommand*)command {
    NSString* callbackId = [command callbackId];
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *model = malloc(size);
    sysctlbyname("hw.machine", model, &size, NULL, 0);
    NSString *deviceModel = [NSString stringWithCString:model encoding:NSUTF8StringEncoding];
    free(model);
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:(CDVCommandStatus_OK)
                               messageAsString:deviceModel];
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

@end
