#import <Syphon/SyphonMetalServer.h>
#import "AAPLShaderTypes.h"
#import "BasicSceneRenderer.h"
#import "BasicMsaaSceneRenderer.h"
#import "TextureRenderer.h"
@import Cocoa;
@import MetalKit;

enum SyphonServerMethod {
    PUBLISH_TEXTURE = 0,
    DRAW_FRAME,
    USE_VIEWDRAWABLE
} SyphonServerMethod;


@interface MetalViewController : NSViewController <MTKViewDelegate>
{
    id <MTLDevice> device;
    MTLPixelFormat colorPixelFormat;
    id <MTLCommandQueue> commandQueue;
    NSSize viewportSize;
    BasicSceneRenderer *basicSceneRenderer;
    BasicMsaaSceneRenderer *basicMsaaSceneRenderer;
    TextureRenderer *textureRenderer;
    SyphonMetalServer *syphonServer;
    enum SyphonServerMethod syphonServerMethod;
}

@property(weak) IBOutlet MTKView *metalView;

@property(readonly) NSString *syphonServerMethodName;

@end
