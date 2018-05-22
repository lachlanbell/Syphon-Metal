#import <Metal/MTLPixelFormat.h>
#import <Foundation/Foundation.h>

#define SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonMetalServer)

@protocol MTLDevice;
@protocol MTLTexture;
@protocol MTLCommandBuffer;

@interface SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME : NSObject

@property (readonly) BOOL hasClients;
@property (retain) NSString* name;
@property (readonly) NSDictionary *serverDescription;

- (id)initWithName:(NSString*)serverName metalDevice:(id<MTLDevice>)metalDevice pixelFormat:(MTLPixelFormat)pixelFormat;

// API Method 1
- (id<MTLTexture>)prepareToDrawFrameOfSize:(NSSize)size;
- (void)publishNewFrame;

// API Method 2
- (void)publishFrameTexture:(id<MTLTexture>)texture imageRegion:(NSRect)region flipped:(BOOL)isFlipped;


- (id<MTLTexture>)newFrameTexture;
- (void)stop;

@end
