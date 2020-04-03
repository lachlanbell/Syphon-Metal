#import "MetalViewController.h"


@implementation MetalViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    device = MTLCreateSystemDefaultDevice();
    if( device == nil )
    {
        NSLog(@"Metal is not supported on this device");
        exit(0);
    }
    colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    commandQueue = [device newCommandQueue];
    basicSceneRenderer = [[BasicSceneRenderer alloc] initWithDevice:device colorPixelFormat:colorPixelFormat];
    textureRenderer = [[TextureRenderer alloc] initWithDevice:device colorPixelFormat:colorPixelFormat];
    
    // METAL VIEW
    self.metalView.device = device;
    self.metalView.colorPixelFormat = colorPixelFormat;
    self.metalView.delegate = self;
    viewportSize = self.metalView.drawableSize;
    
    // needed for the specific USE_VIEWDRAWABLE case (opens texture to optimised blit command inside syphon framework)
    self.metalView.framebufferOnly = NO;
    
    // SYPHON SERVER
    NSDictionary *options = @{@"SyphonServerOptionIsPrivate":@"NO", @"SyphonServerOptionAntialiasSampleCount": @1};
    syphonServer = [[SyphonMetalServer alloc] initWithName:@"MY SERVER NAME" device:device options:options];
    syphonServerMethod = PUBLISH_TEXTURE;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    viewportSize = size;
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> mainCommandBuffer = [commandQueue commandBuffer];
    mainCommandBuffer.label = @"Syphon Server app command Buffer";
    MTLViewport viewport = (MTLViewport){0.0, 0.0, viewportSize.width, viewportSize.height, -1.0, 1.0 };
    const BOOL flip = checkboxFlipButton.intValue ? YES : NO;
    
    // This is the standard mode : you draw inside a texture and give it to Syphon
    if( syphonServerMethod == PUBLISH_TEXTURE )
    {
        MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:colorPixelFormat width:viewportSize.width height:viewportSize.height mipmapped:NO];
        textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        id<MTLTexture> serverTexture = [device newTextureWithDescriptor:textureDescriptor];
        if( serverTexture != nil )
        {
            [basicSceneRenderer renderToTexture:serverTexture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
            [mainCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
                [syphonServer publishFrameTexture:serverTexture flip:flip];
                // alternatively
                // CGRect region = CGRectMake(0, 0, serverTexture.width/2, serverTexture.height);
                // [syphonServer publishFrameTexture:serverTexture imageRegion:region flip:flip];
            }];
        }
    }
    // In this mode, you take care of all the rendering (no flip, no msaa available on the Server side)
    else if( syphonServerMethod == DRAW_INSIDE_SERVER )
    {
        [syphonServer drawFrame:^(id<MTLTexture> texture, id<MTLCommandBuffer> commandBuffer) {
            [basicSceneRenderer renderToTexture:texture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
        } size:viewportSize commandBuffer:mainCommandBuffer];
    }
    // This mode is very straightforward but less stable (frames can arrive in wrong order)
    else if( syphonServerMethod == USE_VIEWDRAWABLE )
    {
        // MTKView flips the texture for some reason
        [basicSceneRenderer renderToTexture:view.currentDrawable.texture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
        [syphonServer publishFrameTexture:view.currentDrawable.texture flip:flip];
    }
    
    // Render the server view
    if( syphonServerMethod != USE_VIEWDRAWABLE )
    {
        id<MTLTexture> serverTexture = [syphonServer newFrameImage];
        if( serverTexture )
        {
            [textureRenderer renderFromTexture:serverTexture inTexture:view.currentDrawable.texture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
        }
    }
    // Commit
    [mainCommandBuffer presentDrawable:view.currentDrawable];
    [mainCommandBuffer commit];
}


#pragma mark interface

- (NSString*)syphonServerMethodName
{
    switch(syphonServerMethod)
    {
        case DRAW_INSIDE_SERVER : return @"DRAW_INSIDE_SERVER";
        case PUBLISH_TEXTURE : return @"PUBLISH_TEXTURE";
        case USE_VIEWDRAWABLE : return @"USE_VIEWDRAWABLE";
        default : return @"???";
    }
}

- (IBAction)updateServerName:(id)sender
{
    // Skip first trigger
    if( [[sender stringValue] isEqualToString:@""] )
    {
        return;
    }
    syphonServer.name = [sender stringValue];
}

- (IBAction)logServerInfo:(id)sender
{
    NSLog(@"========= SERVER =========");
    NSLog(@"Name : %@", syphonServer.name);
    NSLog(@"Clients : %@", syphonServer.hasClients ? @"YES" : @"NO");
    NSLog(@"Description : %@", syphonServer.serverDescription);
    NSLog(@"==========================");
}

- (IBAction)changeSyphonServerMethod:(id)sender
{
    [self willChangeValueForKey:@"syphonServerMethodName"];
    syphonServerMethod = (syphonServerMethod+1)%3;
    [self didChangeValueForKey:@"syphonServerMethodName"];
    // lock useless flip for DRAW_INSIDE_SERVER mode
    if( syphonServerMethod == DRAW_INSIDE_SERVER)
    {
        checkboxFlipButton.intValue = 0;
        checkboxFlipButton.enabled = NO;
    }
    else
    {
        checkboxFlipButton.enabled = YES;
    }
}

@end
