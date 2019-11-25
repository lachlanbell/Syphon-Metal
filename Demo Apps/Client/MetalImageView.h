#import <Cocoa/Cocoa.h>
#import <MetalKit/MTKView.h>

@interface MetalImageView : MTKView

@property (readwrite, assign) id<MTLTexture> image;
// Returns the dimensions the view will render at, including any adjustment for a high-resolution display
@property (readonly) NSSize renderSize;

@end
