#import "haptic.h"
#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>

@interface GodotHaptic : NSObject
@property (strong) CHHapticEngine* engine;
@property (strong) id<CHHapticAdvancedPatternPlayer> continuousPlayer;
@property (strong) id<CHHapticPatternPlayer> patternPlayer;
@property BOOL isEngineStarted;
@property BOOL isEngineIsStopping;
@property BOOL isSupportHaptic;
@end

@implementation GodotHaptic

static GodotHaptic *_shared;

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

        self.isSupportHaptic = @available(iOS 13, *) && CHHapticEngine.capabilitiesForHardware.supportsHaptics;
        #if DEBUG
          NSLog(@"[GodotHaptic] isSupportHaptic -> %d", self.isSupportHaptic);
        #endif

        [self createEngine];
    }
    return self;
}

- (void) dealloc {
  #if DEBUG
      NSLog(@"[GodotHaptic] dealloc");
  #endif

  if (self.isSupportHaptic) {

    self.engine = NULL;
    self.continuousPlayer = NULL;
  }
}

void Haptic::playContinuousHaptic(float intensity, float sharpness, float duration) {
    [[GodotHaptic shared] _playContinuousHaptic:intensity :sharpness :duration];
}

- (void) _playContinuousHaptic:(float) intensity :(float)sharpness :(float)duration {
  #if DEBUG
      NSLog(@"[GodotHaptic] playContinuousHaptic --> intensity: %f, sharpness: %f, isSupportHaptic: %d, engine: %@", intensity, sharpness, self.isSupportHaptic, self.engine);
  #endif

    if (intensity > 1 || intensity <= 0) return;
    if (sharpness > 1 || sharpness < 0) return;
    if (duration <= 0 || duration > 30) return;

    if (self.isSupportHaptic) {

        if (self.engine == NULL) {
            [self createEngine];
        }
        [self startEngine];

        [self createContinuousPlayer:intensity :sharpness :duration];

        NSError* error = nil;
        [_continuousPlayer startAtTime:0 error:&error];
        if (error != nil) {
            NSLog(@"[GodotHaptic] Engine play continuous error --> %@", error);
        }
    }
}

void Haptic::playTransientHaptic(float intensity, float sharpness) {
    [[GodotHaptic shared] _playTransientHaptic:intensity :sharpness];
}

- (void) _playTransientHaptic:(float) intensity :(float)sharpness {
  #if DEBUG
      NSLog(@"[GodotHaptic] playTransientHaptic --> intensity: %f, sharpness: %f, isSupportHaptic: %d, engine: %@", intensity, sharpness, self.isSupportHaptic, self.engine);
  #endif

    if (intensity > 1 || intensity <= 0) return;
    if (sharpness > 1 || sharpness < 0) return;

    if (self.isSupportHaptic) {

        if (self.engine == NULL) {
            [self createEngine];
        }
        [self startEngine];

        CHHapticEventParameter* intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
        CHHapticEventParameter* sharpnessParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharpness];

        CHHapticEvent* event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[intensityParam, sharpnessParam] relativeTime:0];

        NSError* error = nil;
        CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];

        if (error == nil) {
            id<CHHapticPatternPlayer> player = [_engine createPlayerWithPattern:pattern error:&error];

            if (error == nil) {
                [player startAtTime:0 error:&error];
            } else {
                NSLog(@"[GodotHaptic] Create transient player error --> %@", error);
            }
        } else {
            NSLog(@"[GodotHaptic] Create transient pattern error --> %@", error);
        }
    }
}

- (void) playWithDictionaryPattern: (NSDictionary*) hapticDict {
    if (self.isSupportHaptic) {

        if (self.engine == NULL) {
            [self createEngine];
        }
        [self startEngine];

        NSError* error = nil;
        CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithDictionary:hapticDict error:&error];

        if (error == nil) {
            _patternPlayer = [_engine createPlayerWithPattern:pattern error:&error];

            [_engine notifyWhenPlayersFinished:^CHHapticEngineFinishedAction(NSError * _Nullable error) {
                if (error == NULL || error == nil) {
                    return CHHapticEngineFinishedActionLeaveEngineRunning;
                } else {
                    return CHHapticEngineFinishedActionStopEngine;
                }
            }];

            if (error == nil) {
                [_patternPlayer startAtTime:0 error:&error];
            } else {
                NSLog(@"[GodotHaptic] Create dictionary player error --> %@", error);
            }
        } else {
            NSLog(@"[GodotHaptic] Create dictionary pattern error --> %@", error);
        }
    }
}

- (void) playWithDictionaryFromJsonPattern: (NSString*) jsonDict {
    if (jsonDict != nil) {
        #if DEBUG
            NSLog(@"[GodotHaptic] playWithDictionaryFromJsonPattern --> json: %@", jsonDict);
        #endif

        NSError* error = nil;
        NSData* data = [jsonDict dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];

        if (error == nil) {
            [self playWithDictionaryPattern:dict];
        } else {
            NSLog(@"[GodotHaptic] Create dictionary from json error --> %@", error);
        }
    } else {
        NSLog(@"[GodotHaptic] Json dictionary string is nil");
    }
}

- (void) playWIthAHAPFile: (NSString*) fileName {
    if (self.isSupportHaptic) {

        if (self.engine == NULL) {
            [self createEngine];
        }
        [self startEngine];

        NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"ahap"];
        [self playWithAHAPFileFromURLAsString:path];
    }
}

- (void) playWithAHAPFileFromURLAsString: (NSString*) urlAsString {
    if (urlAsString != nil) {
        NSURL* url = [NSURL fileURLWithPath:urlAsString];
        [self playWithAHAPFileFromURL:url];
    } else {
        NSLog(@"[GodotHaptic] url string is nil");
    }
}

- (void) playWithAHAPFileFromURL: (NSURL*) url {
    NSError * error = nil;
    [_engine playPatternFromURL:url error:&error];

    if (error != nil) {
        NSLog(@"[GodotHaptic] Engine play from AHAP file error --> %@", error);
    }
}

void Haptic::updateContinuousHaptic(float intensity, float sharpness){
    [[GodotHaptic shared] _updateContinuousHaptic:intensity :sharpness];
}

- (void) _updateContinuousHaptic:(float) intensity :(float)sharpness {
  #if DEBUG
      NSLog(@"[GodotHaptic] updateContinuousHaptic --> intensity: %f, sharpness: %f, isSupportHaptic: %d, engine: %@", intensity, sharpness, self.isSupportHaptic, self.engine);
  #endif

    if (intensity > 1 || intensity <= 0) return;
    if (sharpness > 1 || sharpness < 0) return;

    if (self.isSupportHaptic && _engine != NULL && _continuousPlayer != NULL) {

        CHHapticDynamicParameter* intensityParam = [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl value:intensity relativeTime:0];
        CHHapticDynamicParameter* sharpnessParam = [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticSharpnessControl value:sharpness relativeTime:0];

        NSError* error = nil;
        [_continuousPlayer sendParameters:@[intensityParam, sharpnessParam] atTime:0 error:&error];

        if (error != nil) {
            NSLog(@"[GodotHaptic] Update continuous parameters error --> %@", error);
        }
    }
}

void Haptic::stop(){
    [[GodotHaptic shared] _stop];
}

- (void) _stop {
    NSLog(@"[GodotHaptic] STOP isSupportHaptic -> %d", self.isSupportHaptic);
    if (self.isSupportHaptic) {

      NSError* error = nil;
      if (_continuousPlayer != NULL)
          [_continuousPlayer stopAtTime:0 error:&error];

      if (_patternPlayer != NULL)
          [_patternPlayer stopAtTime:0 error:&error];

      if (_engine != NULL && _isEngineStarted && !_isEngineIsStopping) {
          GodotHaptic *weakSelf = self;

          _isEngineIsStopping = true;
          [_engine stopWithCompletionHandler:^(NSError *error) {
              if (error != nil) {
                NSLog(@"[GodotHaptic] The engine stopped with error: %@", error);
              }
              weakSelf.isEngineStarted = false;
              weakSelf.isEngineIsStopping = false;
          }];
      }
    }
};

void Haptic::stopPatternPlayer(){
    [[GodotHaptic shared] _stopPatternPlayer];
}

- (void) _stopPatternPlayer {
    NSLog(@"[GodotHaptic] STOP PLAYER isSupportHaptic -> %d, _patternPlayer -> %@", self.isSupportHaptic, _patternPlayer);
    if (self.isSupportHaptic && _patternPlayer != NULL) {
        NSError* error;
        [_patternPlayer stopAtTime:0 error:&error];

        if (error != nil) {
            NSLog(@"[GodotHaptic] Player stop error --> %@", error);
        }
    }
}

- (void) createContinuousPlayer {
    [self createContinuousPlayer: 1.0 :0.5 :30];
}

- (void) createContinuousPlayer:(float) intens :(float)sharp :(float) duration {
    if (self.isSupportHaptic) {
        CHHapticEventParameter* intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intens];
        CHHapticEventParameter* sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:sharp];

        CHHapticEvent* event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensity, sharpness] relativeTime:0 duration:duration];

        NSError* error = nil;
        CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];

        if (error == nil) {
            _continuousPlayer = [_engine createAdvancedPlayerWithPattern:pattern error:&error];
        } else {
            NSLog(@"[GodotHaptic] Create contuous player error --> %@", error);
        }
    }
}

- (void) createEngine {
    if (self.isSupportHaptic) {
        NSError* error = nil;
        _engine = [[CHHapticEngine alloc] initAndReturnError:&error];

        if (error == nil) {

            _engine.playsHapticsOnly = true;
            GodotHaptic *weakSelf = self;

            _engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
                NSLog(@"[GodotHaptic] The engine stopped for reason: %ld", (long)reason);
                switch (reason) {
                    case CHHapticEngineStoppedReasonAudioSessionInterrupt:
                        NSLog(@"[GodotHaptic] Audio session interrupt");
                        break;
                    case CHHapticEngineStoppedReasonApplicationSuspended:
                        NSLog(@"[GodotHaptic] Application suspended");
                        break;
                    case CHHapticEngineStoppedReasonIdleTimeout:
                        NSLog(@"[GodotHaptic] Idle timeout");
                        break;
                    case CHHapticEngineStoppedReasonSystemError:
                        NSLog(@"[GodotHaptic] System error");
                        break;
                    case CHHapticEngineStoppedReasonNotifyWhenFinished:
                        NSLog(@"[GodotHaptic] Playback finished");
                        break;

                    default:
                        NSLog(@"[GodotHaptic] Unknown error");
                        break;
                }

                weakSelf.isEngineStarted = false;
            };

            _engine.resetHandler = ^{
                [weakSelf startEngine];
            };
        } else {
            NSLog(@"[GodotHaptic] Engine init error --> %@", error);
        }
    }
}

- (void) startEngine {
    if (!_isEngineStarted) {
        NSError* error = nil;
        [_engine startAndReturnError:&error];

        if (error != nil) {
            NSLog(@"[GodotHaptic] Engine start error --> %@", error);
        } else {
            _isEngineStarted = true;
        }
    }
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
    // ClassDB::bind_method("playWithDictionaryFromJsonPattern", &Haptic::playWithDictionaryFromJsonPattern);
    // ClassDB::bind_method("playWithAHAPFile", &Haptic::playWithAHAPFile);
    // ClassDB::bind_method("playWithAHAPFileFromURLAsString", &Haptic::playWithAHAPFileFromURLAsString);
    ClassDB::bind_method("stopPatternPlayer", &Haptic::stopPatternPlayer);
    ClassDB::bind_method("stop", &Haptic::stop);
    ClassDB::bind_method("updateContinuousHaptic", &Haptic::updateContinuousHaptic);
}

@end


#pragma mark - Bridge

extern "C" {
    void _coreHapticsGodotPlayContinuous(float intensity, float sharpness, int duration) {
        [[GodotHaptic shared] playContinuousHaptic:intensity :sharpness :duration];
    }

    void _coreHapticsGodotPlayTransient(float intensity, float sharpness) {
        [[GodotHaptic shared] playTransientHaptic:intensity :sharpness];
    }

    void _coreHapticsGodotStop() {
        [[GodotHaptic shared] stop];
    }

    void _coreHapticsGodotStopPlayer() {
        [[GodotHaptic shared] stopPatternPlayer];
    }

    void _coreHapticsGodotupdateContinuousHaptics(float intensity, float sharpness) {
        [[GodotHaptic shared] updateContinuousHaptic:intensity :sharpness];
    }

    void _coreHapticsGodotplayWithDictionaryPattern(const char* jsonDict) {
        [[GodotHaptic shared] playWithDictionaryFromJsonPattern:[[GodotHaptic shared] createNSString:jsonDict]];
    }

    void _coreHapticsGodotplayWIthAHAPFile(const char* filename) {
        [[GodotHaptic shared] playWIthAHAPFile:[[GodotHaptic shared] createNSString:filename]];
    }

    void _coreHapticsGodotplayWithAHAPFileFromURLAsString(const char* urlAsString) {
        [[GodotHaptic shared] playWithAHAPFileFromURLAsString:[[GodotHaptic shared] createNSString:urlAsString]];
    }

    bool _coreHapticsGodotIsSupport() {
        return [[GodotHaptic shared] isSupportHaptic];
    }
}
