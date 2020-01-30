#ifndef HAPTIC_H
#define HAPTIC_H

#include "core/reference.h"

class Haptic : public Reference {
    GDCLASS(Haptic, Reference);

    protected:
        static void _bind_methods();

    public:
        Haptic* shared;
        void playContinuousHaptic(float intensity, float sharpness, float duration);
        void playTransientHaptic(float intensity, float sharpness);
        void playWithDictionaryFromJsonPattern(String jsonDict);
        void playWithAHAPFile(String fileName);
        void playWithAHAPFileFromURLAsString(String urlAsString);
        void stop();
        void updateContinuousHaptic(float intensity, float sharpness);
        bool isSupported();
};

#endif