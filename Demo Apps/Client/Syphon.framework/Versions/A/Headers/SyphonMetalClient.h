#import <Foundation/Foundation.h>
#import <Metal/MTLPixelFormat.h>
#import "SyphonClientBase.h"

@interface SyphonMetalClient : SyphonClientBase

- (id)initWithServerDescription:(NSDictionary *)description device:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat options:(NSDictionary *)options
                frameHandler:(void (^)(SyphonMetalClient *client))handler;

- (id<MTLTexture>)newFrameImage;
- (void)stop;

@end
