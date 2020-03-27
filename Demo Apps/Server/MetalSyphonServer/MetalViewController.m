#import "MetalViewController.h"


@implementation MetalViewController

const Boolean TEST_ANTIALIASING = false;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // METAL PIPELINE
    device = MTLCreateSystemDefaultDevice();
    if( device == nil )
    {
        NSLog(@"Metal is not supported on this device");
        exit(0);
    }
    colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    commandQueue = [device newCommandQueue];
    basicSceneRenderer = [[BasicSceneRenderer alloc] initWithDevice:device colorPixelFormat:colorPixelFormat];
    basicMsaaSceneRenderer = [[BasicMsaaSceneRenderer alloc] initWithDevice:device colorPixelFormat:colorPixelFormat];
    textureRenderer = [[TextureRenderer alloc] initWithDevice:device colorPixelFormat:colorPixelFormat];
    // METAL VIEW
    self.metalView.device = device;
    self.metalView.colorPixelFormat = colorPixelFormat;
    self.metalView.delegate = self;
    viewportSize = self.metalView.drawableSize;
    // needed for the specific USE_VIEWDRAWABLE case (opens texture to blit command)
    self.metalView.framebufferOnly = NO;
    // SYPHON SERVER
    NSDictionary *options = @{@"SyphonServerOptionIsPrivate":@"NO"};
    syphonServer = [[SyphonMetalServer alloc] initWithName:@"MY SERVER NAME" device:device options:options];
    syphonServerMethod = PUBLISH_TEXTURE;
}

#pragma mark Metal

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    viewportSize = size;
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
    id<MTLCommandBuffer> mainCommandBuffer = [commandQueue commandBuffer];
    MTLViewport viewport = (MTLViewport){0.0, 0.0, viewportSize.width, viewportSize.height, -1.0, 1.0 };
    
    // Send Syphon frame: multiple methods
    if( syphonServerMethod == PUBLISH_TEXTURE )
    {
        MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:colorPixelFormat width:viewportSize.width height:viewportSize.height mipmapped:NO];
        textureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        id<MTLTexture> serverTexture = [device newTextureWithDescriptor:textureDescriptor];
        if( serverTexture != nil )
        {
            [self renderToTexture:serverTexture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
            [mainCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
                [syphonServer publishFrameTexture:serverTexture];
                // alternatively
                // CGRect region = CGRectMake(0, 0, serverTexture.width/2, serverTexture.height)
                //  [syphonServer publishFrameTexture:serverTexture imageRegion:region];
            }];
        }
    }
    else if( syphonServerMethod == DRAW_FRAME )
    {
        [syphonServer drawFrame:^(id<MTLTexture> texture, id<MTLCommandBuffer> commandBuffer) {
            [self renderToTexture:texture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
        } size:viewportSize commandBuffer:mainCommandBuffer];
    }
    else if( syphonServerMethod == USE_VIEWDRAWABLE )
    {
        // Texture will appear Y-flipped compared to Syphon output because MTKView does an automatic Y flip when drawing the resulting texture
        [self renderToTexture:view.currentDrawable.texture onCommandBuffer:mainCommandBuffer andViewPort:viewport];
        [syphonServer publishFrameTexture:view.currentDrawable.texture];
    }
    
    // Render view here
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

- (void)renderToTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport
{
    if( TEST_ANTIALIASING )
    {
        [basicMsaaSceneRenderer renderToTexture:texture onCommandBuffer:commandBuffer andViewPort:viewport];
    }
    else
    {
        [basicSceneRenderer renderToTexture:texture onCommandBuffer:commandBuffer andViewPort:viewport];
    }
}


#pragma mark interface

- (NSString*)syphonServerMethodName
{
    switch(syphonServerMethod)
    {
        case DRAW_FRAME : return @"DRAW_FRAME";
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
}

@end
