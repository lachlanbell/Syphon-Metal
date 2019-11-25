#import "MetalImageView.h"
#import "TextureRenderer.h"

@interface MetalImageView ()
{
    id<MTLTexture> _image;
    BOOL _needsReshape;
    TextureRenderer *textureRenderer;
    id <MTLCommandQueue> commandQueue;
}
@property (readwrite) BOOL needsReshape;
@end

@implementation MetalImageView

@synthesize needsReshape = _needsReshape, image = _image;

- (void)awakeFromNib
{
    self.device = MTLCreateSystemDefaultDevice();
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    textureRenderer = [[TextureRenderer alloc] initWithDevice:self.device colorPixelFormat:self.colorPixelFormat];
    commandQueue = [self.device newCommandQueue];
    
    self.needsReshape = YES;
    if ([NSView instancesRespondToSelector:@selector(setWantsBestResolutionOpenGLSurface:)])
    {
        // 10.7+
        [self setWantsBestResolutionOpenGLSurface:YES];
    }
}

- (void)dealloc
{
    _image = nil;
    [super dealloc];
}

- (void)reshape
{
    self.needsReshape = YES;
    [super reshape];
}

- (BOOL)enableSetNeedsDisplay
{
    return YES;
}

- (BOOL)isPaused
{
    return YES;
}
- (NSSize)renderSize
{
    if ([NSView instancesRespondToSelector:@selector(convertRectToBacking:)])
    {
        // 10.7+
        return [self convertSizeToBacking:[self bounds].size];
    }
    else return [self bounds].size;
}

- (void)drawRect:(NSRect)dirtyRect
{
    id<MTLCommandBuffer> mainCommandBuffer = [commandQueue commandBuffer];
    MTLViewport viewport = (MTLViewport){0.0, 0.0, self.bounds.size.width*2, self.bounds.size.height*2, -1.0, 1.0 };
    
    if( _image != nil )
    {
        [textureRenderer renderFromTexture:_image inTexture:self.currentDrawable.texture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
    }
    
    [mainCommandBuffer presentDrawable:self.currentDrawable];
    [mainCommandBuffer commit];
}

@end
