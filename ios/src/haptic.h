#ifndef HAPTIC_H
#define HAPTIC_H

#include "core/reference.h"

class Haptic : public Reference {
    GDCLASS(Haptic, Reference);

    protected:
        static void _bind_methods();

    public:
        Haptic* shared;
        bool isSupportHaptic;
        void playContinuousHaptic(float intensity, float sharpness, float duration);
        void playTransientHaptic(float intensity, float sharpness);
        // void playWithDictionaryFromJsonPattern(String jsonDict);
        // void playWithAHAPFile(String fileName);
        // void playWithAHAPFileFromURLAsString(String urlAsString);
        void stop();
        void stopPatternPlayer();
        void updateContinuousHaptic(float intensity, float sharpness);
};

#endif