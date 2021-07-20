#import "SyphonIOSurfaceServer.h"




@interface SyphonServerBase()
- (void)publishIOSurface:(IOSurfaceRef)ioSurfaceToPublish;
@end




@implementation SYPHON_IOSURFACE_SERVER_UNIQUE_CLASS_NAME

#pragma mark - Public API

- (void)publishIOSurface:(IOSurfaceRef)ioSurfaceToPublish
{
    [super publishIOSurface:ioSurfaceToPublish];
}

@end
