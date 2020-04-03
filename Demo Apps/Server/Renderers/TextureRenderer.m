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
        
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"textureToScreenVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"textureToScreenSamplingShader"];
        
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

- (void)renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport
{
    [self renderFromTexture:offScreenTexture inTexture:texture onCommandBuffer:commandBuffer andViewPort:viewport flip:NO];
}
- (void) renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport flip:(BOOL)flip
{
    _viewportSize.x = viewport.width;
    _viewportSize.y = viewport.height;
    
    const float w = viewport.width/2;
    const float h = viewport.height/2;
    const float flipValue = flip ? -1 : 1;
    
    const AAPLTextureVertex quadVertices[] =
    {
        // Pixel positions (NDC), Texture coordinates
        { {  w,   flipValue * h },  { 1.f, 1.f } },
        { { -w,   flipValue * h },  { 0.f, 1.f } },
        { { -w,  flipValue * -h },  { 0.f, 0.f } },
        
        { {  w,  flipValue * h },  { 1.f, 1.f } },
        { { -w,  flipValue * -h },  { 0.f, 0.f } },
        { {  w,  flipValue * -h },  { 1.f, 0.f } },
    };
    
    NSUInteger numberOfVertices =  sizeof(quadVertices) / sizeof(AAPLTextureVertex);
    
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
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
