#include "haptic.h"

#import "app_delegate.h"
#import <UIKit/UIKit.h>

UISelectionFeedbackGenerator* selectionGenerator = NULL;

Haptic::Haptic() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
	selectionGenerator = [UISelectionFeedbackGenerator new];
}

Haptic::~Haptic() {
    instance = NULL;
	selectionGenerator = NULL;
}

void Haptic::selection() {
    [selectionGenerator selectionChanged];
}

void Haptic::impact(int feedback_style) {
	UIImpactFeedbackGenerator *hap = [[UIImpactFeedbackGenerator alloc] init];

    [hap prepare];

    if(feedback_style == 0) [hap initWithStyle:UIImpactFeedbackStyleLight];

    else if(feedback_style == 1) [hap initWithStyle:UIImpactFeedbackStyleMedium];

    else if(feedback_style == 2) [hap initWithStyle:UIImpactFeedbackStyleHeavy];

	else [hap initWithStyle:UIImpactFeedbackStyleLight];

    [hap impactOccurred];
}

void Haptic::notification(int feedback_type) {
	UINotificationFeedbackGenerator *hap = [[UINotificationFeedbackGenerator alloc] init];

    [hap prepare];

    if(feedback_type == 0) [hap notificationOccurred:UINotificationFeedbackTypeSuccess];

    else if(feedback_type == 1) [hap notificationOccurred:UINotificationFeedbackTypeWarning];

    else if(feedback_type == 2) [hap notificationOccurred:UINotificationFeedbackTypeError];

	else [hap notificationOccurred:UINotificationFeedbackTypeSuccess];
}

void Haptic::_bind_methods() {
    ClassDB::bind_method(D_METHOD("impact"), &Haptic::impact);
	ClassDB::bind_method(D_METHOD("selection"), &Haptic::selection);
	ClassDB::bind_method(D_METHOD("notification"), &Haptic::notification);
}
