#import "CDVHeartBeat.h"
#import "CDVHeartBeatDetection.h"

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
        [heartBeatDetection startDetection];
        
        while(self.detecting){
            
        }
        
        [self.bpms sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
        if(self.error == false) {
            int bpm = [((NSNumber*)self.bpms[self.bpms.count/2]) intValue];
            NSMutableDictionary *jsonObj = [[NSMutableDictionary alloc]initWithCapacity:4];
            [jsonObj setObject:[NSNumber numberWithInt:bpm] forKey:@"bpm"];
            [jsonObj setObject:[NSMutableArray arrayWithArray:self.bfi] forKey:@"bfi"];
            [jsonObj setObject:[NSMutableArray arrayWithArray:self.sbi] forKey:@"sbi"];
            [jsonObj setObject:[NSMutableArray arrayWithArray:self.hue] forKey:@"hue"];
            [heartBeatDetection.returnArray addObject:jsonObj];
        }
        
        NSError *error;
        if(heartBeatDetection.heartBeatError == false) {
            if (!heartBeatDetection.returnArray || !heartBeatDetection.returnArray.count || heartBeatDetection.returnArray.count == 0) {
                CDVPluginResult* resulterror = [CDVPluginResult
                                                resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsString:@"Error detecting your heart beat"];
                
                [self.commandDelegate sendPluginResult:resulterror callbackId:callbackId];
            }
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:heartBeatDetection.returnArray
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
    }];
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
