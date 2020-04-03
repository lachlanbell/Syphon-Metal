#import "BasicSceneRenderer.h"
#import "AAPLShaderTypes.h"

@implementation BasicSceneRenderer
{
    id<MTLRenderPipelineState> pipelineState;
    vector_uint2 _viewportSize;
    float elapsedTime;
}

- (nonnull instancetype)initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self = [super init];
    if( self )
    {
        NSError *error = NULL;
        id<MTLLibrary> defaultLibrary = [device newDefaultLibrary];
        
        // Load the vertex/shader function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"triangleVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"triangleFragmentShader"];
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat;
        
        pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if( !pipelineState )
        {
            NSLog(@"Failed to created triangle pipeline state, error %@", error);
            return nil;
        }
        
        elapsedTime = 10;
    }
    return self;
}

- (void) renderToTexture:(id<MTLTexture>)texture onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer andViewPort:(MTLViewport)viewport
{
    _viewportSize.x = viewport.width;
    _viewportSize.y = viewport.height;
    
    const float sinus = sin(elapsedTime);
    const float psinus = (sinus+1)/2;
    AAPLColorVertex triangleVertices[] =
    {
        // 2D Positions (Normalized Device Coordinate (0,0) is screen center),    RGBA colors
        //
        { {  250*sinus,  -250 }, { 1, 1, 1, 1 } },
        { { -250*sinus,  -250 }, { 0, 0, 1, 1 } },
        { {    0*sinus,   250 }, { psinus, psinus, psinus, 1 } },
    };
    
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].texture = texture;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1-psinus, 1-psinus, 1-psinus, 1.0);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderEncoder.label = @"Syphon Demo Scene renderEncoder";
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:pipelineState];
    [renderEncoder setVertexBytes:triangleVertices length:sizeof(triangleVertices) atIndex:AAPLVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize)atIndex:AAPLVertexInputIndexViewportSize];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [renderEncoder endEncoding];
    
    elapsedTime += 0.02;
    if(3E+38 < elapsedTime)
    {
        elapsedTime = 0;
    }
}

@end
