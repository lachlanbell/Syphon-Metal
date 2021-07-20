#import "SyphonServerBase.h"


NS_ASSUME_NONNULL_BEGIN

#define SYPHON_IOSURFACE_SERVER_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonIOSurfaceServer)
@interface SYPHON_IOSURFACE_SERVER_UNIQUE_CLASS_NAME : SyphonServerBase

/*!
 Returns a new client instance for the described server. You should check the isValid property after initialization to ensure a connection was made to the server.
 @param ioSurfaceToPublish The IOSurfaceRef you wish to publish on the server.
*/
- (void)publishIOSurface:(IOSurfaceRef)ioSurfaceToPublish;

@end

NS_ASSUME_NONNULL_END
