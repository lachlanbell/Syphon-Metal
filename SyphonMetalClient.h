#import <Foundation/Foundation.h>
#import <Metal/MTLPixelFormat.h>

#define SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonMetalClient)

@protocol MTLDevice;

@interface SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME : NSObject
{
@private
    id                _connectionManager;
    NSUInteger        _lastFrameID;
    void            (^_handler)(id);
    int32_t            _status;
    int32_t            _lock;
    id<MTLTexture> _frame;
    int32_t         _frameValid;
    NSDictionary    *_serverDescription;
    id<MTLDevice>   device;
    MTLPixelFormat  colorPixelFormat;
}

@property (readonly) BOOL isValid;
@property (readonly) NSDictionary *serverDescription;
@property (readonly) BOOL hasNewFrame;

/*!
 Returns a new client instance for the described server. You should check the isValid property after initialization to ensure a connection was made to the server.
 @param description Typically acquired from the shared SyphonServerDirectory, or one of Syphon's notifications.
 @param context The CGLContextObj context to create textures for.
 @param options Currently ignored. May be nil.
 @param handler A block which is invoked when a new frame becomes available. handler may be nil. This block may be invoked on a thread other than that on which the client was created.
 @returns A newly initialized SyphonClient object, or nil if a client could not be created.
 */

- (id)initWithServerDescription:(NSDictionary *)description device:(id<MTLDevice>)device pixelFormat:(MTLPixelFormat)colorPixelFormat options:(NSDictionary *)options
                newFrameHandler:(void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler;
- (id<MTLTexture>)newFrameImage;
- (void)stop;

@end


#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonMetalClient SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME;
#endif

