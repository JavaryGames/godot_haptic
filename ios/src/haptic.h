#ifndef HAPTIC_H
#define HAPTIC_H

#include "core/reference.h"

class Haptic : public Reference {
    GDCLASS(Haptic, Reference);

    protected:
        static void _bind_methods();

		Haptic* instance;

    public:
        void selection();
		void impact(int feedback_style);
		void notification(int feedback_type);

		Haptic();
        ~Haptic();
};

#endif