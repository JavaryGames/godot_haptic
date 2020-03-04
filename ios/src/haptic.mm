#import "haptic.h"
#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>

@interface GodotHaptic : NSObject
@property (strong) CHHapticEngine* engine;
@property (strong) id<CHHapticAdvancedPatternPlayer> continuousPlayer;
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

bool Haptic::isSupported() {
    return [[GodotHaptic shared] _isSupported];
}

- (BOOL) _isSupported {
    return self.isSupportHaptic;
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

        [_engine notifyWhenPlayersFinished:^CHHapticEngineFinishedAction(NSError * _Nullable error) {
            [self releaseContinuousPlayer];
            if (error == NULL || error == nil) {
                return CHHapticEngineFinishedActionLeaveEngineRunning;
            } else {
                return CHHapticEngineFinishedActionStopEngine;
            }
        }];

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

void Haptic::updateContinuousHaptic(float intensity, float sharpness) {
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

void Haptic::stop() {
    [[GodotHaptic shared] _stop];
}

- (void) _stop {
    NSLog(@"[GodotHaptic] STOP isSupportHaptic -> %d", self.isSupportHaptic);
    if (self.isSupportHaptic) {

      NSError* error = nil;
      if (_continuousPlayer != NULL)
          [_continuousPlayer stopAtTime:0 error:&error];

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
            [_continuousPlayer retain];
        } else {
            NSLog(@"[GodotHaptic] Create contuous player error --> %@", error);
        }
    }
}

- (void) releaseContinuousPlayer {
    NSLog(@"[GodotHaptic] Releasing continuous player");
    [_continuousPlayer release];
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

void Haptic::_bind_methods() {
    ClassDB::bind_method("isSupported", &Haptic::isSupported);
    ClassDB::bind_method("playContinuousHaptic", &Haptic::playContinuousHaptic);
    ClassDB::bind_method("playTransientHaptic", &Haptic::playTransientHaptic);
    ClassDB::bind_method("updateContinuousHaptic", &Haptic::updateContinuousHaptic);
    ClassDB::bind_method("stop", &Haptic::stop);
}

@end
