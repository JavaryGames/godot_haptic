#import "haptic.h"
#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>

@interface GodotHaptic : NSObject
@property (nonatomic, strong) CHHapticEngine* engine;
@property (nonatomic, strong) id<CHHapticAdvancedPatternPlayer> continuousPlayer;
@property (nonatomic) BOOL isEngineStarted;
@end

@implementation GodotHaptic

static GodotHaptic * _shared;

+ (GodotHaptic*) shared {
    @synchronized (self) {
        if(_shared == nil) {
            _shared = [[self alloc] init];
        }
    }
    return _shared;
}

- (id) init {
    if (self == [super init]) {
        [self createEngine];
    }
    return self;
}

void Haptic::playContinuousHaptic(float intensity, float sharpness, float duration) {
#if DEBUG
    NSLog(@"[Haptic] playContinuousHaptic --> intensity: %f, sharpness: %f, isSupportHaptic: %d, engine: %@", intensity, sharpness, [[GodotHaptic shared] isSupportHaptic], [GodotHaptic shared].engine);
#endif

    if (intensity > 1 || intensity <= 0) return;
    if (sharpness > 1 || sharpness < 0) return;
    if (duration <= 0 || duration > 30) return;

    if ([[GodotHaptic shared] isSupportHaptic]) {
        if ([GodotHaptic shared].engine == NULL) {
            [[GodotHaptic shared] createEngine];
        }
        [[GodotHaptic shared] startEngine];

        [[GodotHaptic shared] createContinuousPlayer:intensity :sharpness :duration];

        NSError* error = nil;
        [[GodotHaptic shared].continuousPlayer startAtTime:0 error:&error];

        if (error != nil) {
            NSLog(@"[Haptic] Engine play continuous error --> %@", error);
        }
    }
}

void Haptic::playTransientHaptic(float intensity, float sharpness) {
  #if DEBUG
      NSLog(@"[Haptic] playTransientHaptic --> intensity: %f, sharpness: %f, isSupportHaptic: %d, engine: %@", intensity, sharpness, [[GodotHaptic shared] isSupportHaptic], [GodotHaptic shared].engine);
  #endif

    if (intensity > 1 || intensity <= 0) return;
    if (sharpness > 1 || sharpness < 0) return;

    if ([[GodotHaptic shared] isSupportHaptic]) {

        if ([GodotHaptic shared].engine == NULL) {
            [[GodotHaptic shared] createEngine];
        }
        [[GodotHaptic shared] startEngine];

        CHHapticEventParameter* intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
        CHHapticEventParameter* sharpnessParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharpness];

        CHHapticEvent* event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[intensityParam, sharpnessParam] relativeTime:0];

        NSError* error = nil;
        CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];

        if (error == nil) {
            id<CHHapticPatternPlayer> player = [[GodotHaptic shared].engine createPlayerWithPattern:pattern error:&error];

            if (error == nil) {
                [player startAtTime:0 error:&error];
            } else {
                NSLog(@"[Haptic] Create transient player error --> %@", error);
            }
        } else {
            NSLog(@"[Haptic] Create transient pattern error --> %@", error);
        }
    }
}

- (void) playWithDictionaryPattern: (NSDictionary*) hapticDict {
    if ([self isSupportHaptic]) {

        if (self.engine == NULL) {
            [self createEngine];
        }
        [self startEngine];

        NSError* error = nil;
        CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithDictionary:hapticDict error:&error];

        if (error == nil) {
            id<CHHapticPatternPlayer> player = [_engine createPlayerWithPattern:pattern error:&error];

            [_engine notifyWhenPlayersFinished:^CHHapticEngineFinishedAction(NSError * _Nullable error) {
                if (error == NULL || error == nil) {
                    return CHHapticEngineFinishedActionLeaveEngineRunning;
                } else {
                    return CHHapticEngineFinishedActionStopEngine;
                }
            }];

            if (error == nil) {
                [player startAtTime:0 error:&error];
            } else {
                NSLog(@"[Haptic] Create dictionary player error --> %@", error);
            }
        } else {
            NSLog(@"[Haptic] Create dictionary pattern error --> %@", error);
        }
    }
}

void Haptic::playWithDictionaryFromJsonPattern(String jsonDict) {
    NSString* ns_jsonDict = [NSString stringWithCString: jsonDict.utf8().get_data()];
    if (ns_jsonDict != nil) {
        #if DEBUG
            NSLog(@"[Haptic] playWithDictionaryFromJsonPattern --> json: %@", ns_jsonDict);
        #endif

        NSError* error = nil;
        NSData* data = [ns_jsonDict dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];

        if (error == nil) {
            [[GodotHaptic shared] playWithDictionaryPattern:dict];
        } else {
            NSLog(@"[Haptic] Create dictionary from json error --> %@", error);
        }
    } else {
        NSLog(@"[Haptic] Json dictionary string is nil");
    }
}

void Haptic::playWithAHAPFile(String fileName) {
    NSString* ns_fileName = [NSString stringWithCString: fileName.utf8().get_data()];
    if ([[GodotHaptic shared] isSupportHaptic]) {

        if ([GodotHaptic shared].engine == NULL) {
            [[GodotHaptic shared] createEngine];
        }
        [[GodotHaptic shared] startEngine];

        NSString* path = [[NSBundle mainBundle] pathForResource:ns_fileName ofType:@"ahap"];
        [[GodotHaptic shared] playWithAHAPFileFromURLAsString:path];
    }
}

void Haptic::playWithAHAPFileFromURLAsString(String urlAsString) {
    NSString* ns_urlAsString = [NSString stringWithCString: urlAsString.utf8().get_data()];
    if (ns_urlAsString != nil) {
        NSURL* url = [NSURL fileURLWithPath:ns_urlAsString];
        [[GodotHaptic shared] playWithAHAPFileFromURL:url];
    } else {
        NSLog(@"[Haptic] url string is nil");
    }
}

- (void) playWithAHAPFileFromURL: (NSURL*) url {
    NSError * error = nil;
    [_engine playPatternFromURL:url error:&error];

    if (error != nil) {
        NSLog(@"[Haptic] Engine play from AHAP file error --> %@", error);
    }
}

void Haptic::updateContinuousHaptic(float intensity, float sharpness) {
  #if DEBUG
      NSLog(@"[Haptic] updateContinuousHaptic --> intensity: %f, sharpness: %f, isSupportHaptic: %d, engine: %@, player: %@", intensity, sharpness, [[GodotHaptic shared] isSupportHaptic], [GodotHaptic shared].engine, [GodotHaptic shared].continuousPlayer);
  #endif

    if (intensity > 1 || intensity <= 0) return;
    if (sharpness > 1 || sharpness < 0) return;

    if ([[GodotHaptic shared] isSupportHaptic] && [GodotHaptic shared].engine != NULL && [GodotHaptic shared].continuousPlayer != NULL) {

        CHHapticDynamicParameter* intensityParam = [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl value:intensity relativeTime:0];
        CHHapticDynamicParameter* sharpnessParam = [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticSharpnessControl value:sharpness relativeTime:0];

        NSError* error = nil;
        [[GodotHaptic shared].continuousPlayer sendParameters:@[intensityParam, sharpnessParam] atTime:0 error:&error];

        if (error != nil) {
            NSLog(@"[Haptic] Update contuous parameters error --> %@", error);
        }
    }
}

void Haptic::stop() {
    if ([[GodotHaptic shared] isSupportHaptic]) {

        [[GodotHaptic shared] createContinuousPlayer];
        NSError* error = nil;
        [[GodotHaptic shared].continuousPlayer stopAtTime:0 error:&error];

        if ([GodotHaptic shared].engine != NULL && [GodotHaptic shared].isEngineStarted) {
            GodotHaptic *weakSelf = [GodotHaptic shared];

            [[GodotHaptic shared].engine stopWithCompletionHandler:^(NSError *error) {
                NSLog(@"[Haptic] The engine stopped with error: %@", error);
                weakSelf.isEngineStarted = false;
            }];
        }
    }
}

- (void) createContinuousPlayer {
    [self createContinuousPlayer: 1.0 :0.5 :30];
}

- (void) createContinuousPlayer:(float) intens :(float)sharp :(float) duration {
    if ([self isSupportHaptic]) {
        CHHapticEventParameter* intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intens];
        CHHapticEventParameter* sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharp];

        CHHapticEvent* event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensity, sharpness] relativeTime:0 duration:duration];

        NSError* error = nil;
        CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];

        if (error == nil) {
            _continuousPlayer = [_engine createAdvancedPlayerWithPattern:pattern error:&error];
        } else {
            NSLog(@"[Haptic] Create contuous player error --> %@", error);
        }
    }
}

- (void) createEngine {
    if ([self isSupportHaptic]) {
        NSError* error = nil;
        _engine = [[CHHapticEngine alloc] initAndReturnError:&error];

        if (error == nil) {

            _engine.playsHapticsOnly = true;
            GodotHaptic *weakSelf = self;

            _engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
                NSLog(@"[Haptic] The engine stopped for reason: %ld", (long)reason);
                switch (reason) {
                    case CHHapticEngineStoppedReasonAudioSessionInterrupt:
                        NSLog(@"[Haptic] Audio session interrupt");
                        break;
                    case CHHapticEngineStoppedReasonApplicationSuspended:
                        NSLog(@"[Haptic] Application suspended");
                        break;
                    case CHHapticEngineStoppedReasonIdleTimeout:
                        NSLog(@"[Haptic] Idle timeout");
                        break;
                    case CHHapticEngineStoppedReasonSystemError:
                        NSLog(@"[Haptic] System error");
                        break;
                    case CHHapticEngineStoppedReasonNotifyWhenFinished:
                        NSLog(@"[Haptic] Playback finished");
                        break;

                    default:
                        NSLog(@"[Haptic] Unknown error");
                        break;
                }

                weakSelf.isEngineStarted = false;
            };

            _engine.resetHandler = ^{
                [weakSelf startEngine];
            };
        } else {
            NSLog(@"[Haptic] Engine init error --> %@", error);
        }
    }
}

- (void) startEngine {
    if (!_isEngineStarted) {
        NSError* reseterror = nil;
        [_engine startAndReturnError:&reseterror];

        if (reseterror != nil) {
            NSLog(@"[Haptic] Engine reset error --> %@", reseterror);
        } else {
            _isEngineStarted = true;
        }
    }
}

- (BOOL) isSupportHaptic {
    if (@available(iOS 13, *)) {
        return CHHapticEngine.capabilitiesForHardware.supportsHaptics;
    }
    return NO;
}

bool Haptic::isSupported() {
    if (@available(iOS 13, *)) {
        return YES;
    }
    return NO;
}

- (NSString*) createNSString: (const char*) string {
  if (string)
      return [[NSString alloc] initWithUTF8String:string];
  else
      return [NSString stringWithUTF8String: ""];
}

void Haptic::_bind_methods() {
    ClassDB::bind_method("playContinuousHaptic", &Haptic::playContinuousHaptic);
    ClassDB::bind_method("playTransientHaptic", &Haptic::playTransientHaptic);
    ClassDB::bind_method("playWithDictionaryFromJsonPattern", &Haptic::playWithDictionaryFromJsonPattern);
    ClassDB::bind_method("playWithAHAPFile", &Haptic::playWithAHAPFile);
    ClassDB::bind_method("playWithAHAPFileFromURLAsString", &Haptic::playWithAHAPFileFromURLAsString);
    ClassDB::bind_method("stop", &Haptic::stop);
    ClassDB::bind_method("updateContinuousHaptic", &Haptic::updateContinuousHaptic);
    ClassDB::bind_method("isSupported", &Haptic::isSupported);
}

@end

#pragma mark - Bridge

extern "C" {
    void _coreHapticsPlayContinuous(float intensity, float sharpness, int duration) {
        [[GodotHaptic shared] playContinuousHaptic:intensity :sharpness :duration];
    }

    void _coreHapticsPlayTransient(float intensity, float sharpness) {
        [[GodotHaptic shared] playTransientHaptic:intensity :sharpness];
    }

    void _coreHapticsStop() {
        [[GodotHaptic shared] stop];
    }

    void _coreHapticsupdateContinuousHaptics(float intensity, float sharpness) {
        [[GodotHaptic shared] updateContinuousHaptic:intensity :sharpness];
    }

    void _coreHapticsplayWithDictionaryPattern(const char* jsonDict) {
        [[GodotHaptic shared] playWithDictionaryFromJsonPattern:[[GodotHaptic shared] createNSString:jsonDict]];
    }

    void _coreHapticsplayWithAHAPFile(const char* filename) {
        [[GodotHaptic shared] playWithAHAPFile:[[GodotHaptic shared] createNSString:filename]];
    }

    void _coreHapticsplayWithAHAPFileFromURLAsString(const char* urlAsString) {
        [[GodotHaptic shared] playWithAHAPFileFromURLAsString:[[GodotHaptic shared] createNSString:urlAsString]];
    }

    bool _coreHapticsIsSupport() {
        return [GodotHaptic isSupported];
    }
}
