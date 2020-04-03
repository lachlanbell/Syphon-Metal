#import <Syphon/SyphonMetalServer.h>
#import "AAPLShaderTypes.h"
#import "BasicSceneRenderer.h"
#import "TextureRenderer.h"
@import Cocoa;
@import MetalKit;

enum SyphonServerMethod {
    PUBLISH_TEXTURE = 0,
    DRAW_INSIDE_SERVER,
    USE_VIEWDRAWABLE
} SyphonServerMethod;


@interface MetalViewController : NSViewController <MTKViewDelegate>
{
    id <MTLDevice> device;
    MTLPixelFormat colorPixelFormat;
    id <MTLCommandQueue> commandQueue;
    NSSize viewportSize;
    BasicSceneRenderer *basicSceneRenderer;
    TextureRenderer *textureRenderer;
    enum SyphonServerMethod syphonServerMethod;
    __weak IBOutlet NSButton *checkboxFlipButton;
    SyphonMetalServer *syphonServer;
}

@property(weak) IBOutlet MTKView *metalView;
@property(readonly) NSString *syphonServerMethodName;

@end
