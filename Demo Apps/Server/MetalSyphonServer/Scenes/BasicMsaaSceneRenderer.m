#import "BasicMsaaSceneRenderer.h"
#import "AAPLShaderTypes.h"

static const int SAMPLE_COUNT = 4;
@implementation BasicMsaaSceneRenderer
{
    id<MTLRenderPipelineState> pipelineState;
    // The current size of our view so we can use this in our render pipeline
    vector_uint2 _viewportSize;
    float elapsedTime;
    id<MTLDevice> device;
    MTLPixelFormat colorPixelFormat;
}

- (nonnull instancetype)initWithDevice:(id<MTLDevice>)theDevice colorPixelFormat:(MTLPixelFormat)TheColorPixelFormat
{
    self = [super init];
    if( self )
    {
        NSError *error = NULL;
        device = theDevice;
        colorPixelFormat = TheColorPixelFormat;
        id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
        
        // Load the vertex/shader function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"triangleVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"triangleFragmentShader"];
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat;
        pipelineStateDescriptor.sampleCount = SAMPLE_COUNT;
        pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if( !pipelineState )
        {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            NSLog(@"Failed to created triangle pipeline state, error %@", error);
            return nil;
        }
        
        
        
        elapsedTime = 0;
    }
    return self;
}

- (void)renderToTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport
{
    _viewportSize.x = viewport.width;
    _viewportSize.y = viewport.height;
    
    float sinus = sin(elapsedTime);
    float psinus = (sinus+1)/2;
    AAPLColorVertex triangleVertices[] =
    {
        // 2D Positions,    RGBA colors
        { {  250*sinus,  -250 }, { 1, 1, 1, 1 } },
        { { -250*sinus,  -250 }, { 0, 0, 1, 1 } },
        { {    0*sinus,   250 }, { psinus, psinus, psinus, 1 } },
    };
    
    MTLTextureDescriptor *msaaTextureDescriptor =  [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:colorPixelFormat width:viewport.width height:viewport.height mipmapped:YES];
    msaaTextureDescriptor.mipmapLevelCount = 1;
    msaaTextureDescriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    msaaTextureDescriptor.textureType = MTLTextureType2DMultisample;
    msaaTextureDescriptor.sampleCount = SAMPLE_COUNT;
    msaaTextureDescriptor.resourceOptions = MTLResourceStorageModePrivate;
    
    id<MTLTexture> msaaTexture = [device newTextureWithDescriptor:msaaTextureDescriptor];
    
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = msaaTexture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1-psinus, 1-psinus, 1-psinus, 1.0);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
    renderPassDescriptor.colorAttachments[0].resolveTexture = texture;
    
    // Create a render command encoder so we can render into something
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:pipelineState];
    [renderEncoder setVertexBytes:triangleVertices length:sizeof(triangleVertices) atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize)atIndex:AAPLVertexInputIndexViewportSize];
    // Draw the 3 vertices of our triangle
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [renderEncoder endEncoding];
    
    elapsedTime+=0.02;
}
@end

