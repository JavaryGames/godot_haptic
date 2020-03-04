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
        bool isSupported();
        void playContinuousHaptic(float intensity, float sharpness, float duration);
        void playTransientHaptic(float intensity, float sharpness);
        void updateContinuousHaptic(float intensity, float sharpness);
        void stop();
};

#endif