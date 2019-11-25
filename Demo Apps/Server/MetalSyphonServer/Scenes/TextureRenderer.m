#import "TextureRenderer.h"
#import "AAPLShaderTypes.h"

@implementation TextureRenderer
{
    vector_uint2 _viewportSize;
    id<MTLRenderPipelineState> pipelineState;
}

- (nonnull instancetype)initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self = [super init];
    if( self )
    {
        NSError *error = NULL;
        id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
        
        // Load the vertex/fragment functions from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"textureToScreenVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"textureToScreenSamplingShader"];
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat;
        pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        if( !pipelineState )
        {
            NSLog(@"Failed to created screen2Tex pipeline state, error %@", error);
            return nil;
        }
    }
    return self;
}

- (void) renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport;
{
    _viewportSize.x = viewport.width;
    _viewportSize.y = viewport.height;
    
    float w = viewport.width/2;
    float h = viewport.height/2;
    
    const AAPLTextureVertex quadVertices[] =
    {
        // Pixel positions, Texture coordinates
        { {  w,   h },  { 1.f, 1.f } },
        { { -w,   h },  { 0.f, 1.f } },
        { { -w,  -h },  { 0.f, 0.f } },
        
        { {  w,   h },  { 1.f, 1.f } },
        { { -w,  -h },  { 0.f, 0.f } },
        { {  w,  -h },  { 1.f, 0.f } },
    };
    NSUInteger numberOfVertices =  sizeof(quadVertices) / sizeof(AAPLTextureVertex);
    
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    // Create a render command encoder so we can render into something
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:pipelineState];
    [renderEncoder setVertexBytes:quadVertices length:sizeof(quadVertices) atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize)atIndex:AAPLVertexInputIndexViewportSize];
    [renderEncoder setFragmentTexture:offScreenTexture atIndex:AAPLTextureIndexBaseColor];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:numberOfVertices];
    [renderEncoder endEncoding];
}
@end
