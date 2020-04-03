#import <Foundation/Foundation.h>

@import Metal;

@interface BasicSceneRenderer : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat;
- (void)renderToTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport;

@end
