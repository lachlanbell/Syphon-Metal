#import <Foundation/Foundation.h>

@import Metal;

@interface TextureRenderer : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat;
- (void)renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport;
- (void)renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport flip:(BOOL)flip;

@end
