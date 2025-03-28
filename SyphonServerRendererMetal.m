#import "SyphonServerRendererMetal.h"
#import <Metal/Metal.h>
#include <simd/simd.h>

typedef enum SYPHONVertexInputIndex
{
    SYPHONVertexInputIndexVertices     = 0,
    SYPHONVertexInputIndexViewportSize =  1,
} SYPHONVertexInputIndex;


typedef enum SYPHONTextureIndex
{
    SYPHONTextureIndexZero = 0,
} SYPHONTextureIndex;

typedef struct
{
    vector_float2 position;
    vector_float4 color;
} SYPHONColorVertex;

typedef struct
{
    vector_float2 position;
    vector_float2 textureCoordinate;
} SYPHONTextureVertex;

NSString *types = @""
"#include <simd/simd.h>\n"
"typedef enum SyphonVertexInputIndex\n"
"{"
"    SYPHONVertexInputIndexVertices     = 0,\n"
"    SYPHONVertexInputIndexViewportSize =  1,\n"
"} SYPHONVertexInputIndex;\n"
"typedef enum SyphonTextureIndex\n"
"{"
"    SYPHONTextureIndexZero = 0,\n"
"} SYPHONTextureIndex;\n"
"typedef struct\n"
"{"
"    vector_float2 position;\n"
"    vector_float4 color;\n"
"} SYPHONColorVertex;\n"
"typedef struct\n"
"{"
"    vector_float2 position;\n"
"    vector_float2 textureCoordinate;\n"
"} SYPHONTextureVertex;\n";

NSString *shaderCode = @""
"#include <metal_stdlib>\n"
"#include <simd/simd.h>\n"
"using namespace metal;\n"
"typedef struct\n"
"{"
"    float4 clipSpacePosition [[position]];\n"
"    float4 color;\n"
"    float2 textureCoordinate;\n"
"} RasterizerData;\n"
"vertex RasterizerData textureToScreenVertexShader(uint vertexID [[ vertex_id ]], constant SYPHONTextureVertex *vertexArray [[ buffer(SYPHONVertexInputIndexVertices) ]], constant vector_uint2 *viewportSizePointer  [[ buffer(SYPHONVertexInputIndexViewportSize) ]]){"
"RasterizerData out;"
"float2 pixelSpacePosition = vertexArray[vertexID].position.xy;"
"float2 viewportSize = float2(*viewportSizePointer);"
"out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);"
"out.clipSpacePosition.z = 0.0;"
"out.clipSpacePosition.w = 1.0;"
"out.textureCoordinate = vertexArray[vertexID].textureCoordinate;"
"return out;"
"}\n"

"fragment float4 textureToScreenSamplingShader(RasterizerData in [[stage_in]], texture2d<half> colorTexture [[ texture(SYPHONTextureIndexZero) ]]) {"
"    constexpr sampler textureSampler (mag_filter::nearest, min_filter::nearest);"
"    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);"
"    return float4(colorSample);"
"}";

@implementation SyphonServerRendererMetal
{
    id<MTLRenderPipelineState> _pipelineState;
    MTLPixelFormat _colorPixelFormat;
    vector_uint2 _viewportSize;
    id<MTLDevice> _device;
}

- (nonnull instancetype)initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self = [super init];
    if( self )
    {
        _colorPixelFormat = colorPixelFormat;
        _device = device;

        NSError *error = NULL;
        NSString *code = [types stringByAppendingString:shaderCode];
        MTLCompileOptions *compileOptions = [MTLCompileOptions new];
        compileOptions.languageVersion = MTLLanguageVersion1_2;
        id<MTLLibrary> defaultLibrary = [device newLibraryWithSource:code options:compileOptions error:&error];
        if( error )
        {
            SYPHONLOG(@"METAL SHADER COMPILER ERROR:%@", error);
        }
        
        // Load the vertex/shader function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"textureToScreenVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"textureToScreenSamplingShader"];
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
        pipelineStateDescriptor.label = @"Syphon Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat;
        
        _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        if( !_pipelineState )
        {
            SYPHONLOG(@"Failed to createe pipeline state, error %@", error);
            return nil;
        }
    }
    return self;
}

- (void)renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture region:(NSRect)region onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer flip:(BOOL)flip
{
    if( texture == nil )
    {
        return;
    }
    
    const MTLViewport viewport = (MTLViewport){region.origin.x, region.origin.y, region.size.width, region.size.height, -1.0, 1.0 };
    _viewportSize.x = viewport.width;
    _viewportSize.y = viewport.height;
    
    const float w = viewport.width/2;
    const float h = viewport.height/2;
    const float flipValue = flip ? 1 : -1;
    
    const SYPHONTextureVertex quadVertices[] =
    {
        // Pixel positions (NDC), Texture coordinates
        { {  w,   flipValue * h },  { 1.f, 1.f } },
        { { -w,   flipValue * h },  { 0.f, 1.f } },
        { { -w,  flipValue * -h },  { 0.f, 0.f } },
        
        { {  w,  flipValue * h },  { 1.f, 1.f } },
        { { -w,  flipValue * -h },  { 0.f, 0.f } },
        { {  w,  flipValue * -h },  { 1.f, 0.f } },
    };
    
    const NSUInteger numberOfVertices = sizeof(quadVertices) / sizeof(SYPHONTextureVertex);
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    renderPassDescriptor.colorAttachments[0].texture = texture;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // Create a render command encoder so we can render into something
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderEncoder.label = @"Syphon Server Render Encoder";
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBytes:quadVertices length:sizeof(quadVertices) atIndex:SYPHONVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize) atIndex:SYPHONVertexInputIndexViewportSize];
    [renderEncoder setFragmentTexture:offScreenTexture atIndex:SYPHONTextureIndexZero];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:numberOfVertices];
    [renderEncoder endEncoding];
}

@end
