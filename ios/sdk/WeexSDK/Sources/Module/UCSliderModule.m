//
//  UCSliderModule.m
//  Portal
//
//  Created by flycao on 2017/7/4.
//

#import "UCSliderModule.h"
#import "WXSliderComponent.h"
#import "WXSDKManager.h"
#import "WXSDKInstance_private.h"

@implementation UCSliderModule
@synthesize weexInstance;

WX_EXPORT_METHOD(@selector(setCurrentIndex:elemRef:))

- (void)setCurrentIndex:(NSInteger)currentIndex elemRef:(NSString *)elemRef{
    if (!elemRef) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    WXPerformBlockOnComponentThread(^{
        WXSliderComponent *slider = (WXSliderComponent *)[weakSelf.weexInstance componentForRef:elemRef];
        if (!slider) {
            return;
        }
        
        [weakSelf performSelectorOnMainThread:@selector(doBlock:) withObject:^() {
            [slider setSliderIndex:currentIndex];
        } waitUntilDone:NO];
    });

}

- (void)doBlock:(void (^)())block {
    block();
}

@end
