// BrightnessController.m

#import "BrightnessController.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>

//#import <IOKit/i2c/IODALAccess.h>

@implementation BrightnessController

/**
 @param brightnessValue this value controls the screen brightness with 0 being minimum brightness and 1 being maximum brightness
 */
+ (void)setScreenBrightness:(float)brightnessValue {
    io_iterator_t iterator;
    kern_return_t result = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator);
    
    // If we were successful
    if (result == kIOReturnSuccess)
    {
        io_object_t service;
        while ((service = IOIteratorNext(iterator))) {
            // Print the current brightness of the screen
            float current_brightness;
            IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &current_brightness);
            printf("current brightness: %.0f%%\n", current_brightness * 100);

            IODisplaySetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), brightnessValue);
            
            // Print the custom brightness of the screen
            IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey),
                                                &current_brightness);
            printf("new custom brightness: %.0f%%\n", current_brightness * 100);

            // Let the object go
            IOObjectRelease(service);
        }
    }
}

@end
