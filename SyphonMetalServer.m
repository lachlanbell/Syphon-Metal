#import "SyphonMetalServer.h"
#import "SyphonServerConnectionManager.h"
#import <Metal/MTLDevice.h>
#import <Metal/MTLTexture.h>
#import <Metal/MTLCommandQueue.h>
#import "SyphonServerRendererMetal.h"

@interface SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME()
{
    NSString *_name;
    NSString *_uuid;
    IOSurfaceRef _surfaceRef;
    id <MTLTexture> _surfaceTexture;
    SyphonServerConnectionManager *_connectionManager;
    id<MTLDevice> _device;
    MTLPixelFormat _pixelFormat;
    id<MTLCommandQueue> _commandQueue;
    BOOL surfaceHasChanged;
    int32_t threadLock;
    SyphonServerRendererMetal *_renderer;
}

@end

@implementation SYPHON_METAL_SERVER_UNIQUE_CLASS_NAME

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - setups and destroys

- (id)initWithName:(NSString *)serverName metalDevice:(id<MTLDevice>)metalDevice pixelFormat:(MTLPixelFormat)pixelFormat
{
    self = [super init];
    if( self )
    {
        if( serverName == nil )
        {
            serverName = @"";
        }
        
        _device = metalDevice;
        _pixelFormat = pixelFormat;
        _commandQueue = [_device newCommandQueue];
        
        _name = [serverName copy];
        _uuid = SyphonCreateUUIDString();
        
        _surfaceRef = NULL;
        _surfaceTexture = nil;
        surfaceHasChanged = NO;
        threadLock = OS_SPINLOCK_INIT;
        
        _connectionManager = [[SyphonServerConnectionManager alloc] initWithUUID:_uuid options:nil];
        [_connectionManager addObserver:self forKeyPath:@"hasClients" options:NSKeyValueObservingOptionPrior context:nil];
        
        if( ![_connectionManager start] )
        {
            [self release];
            return nil;
        }
        
        [self startBroadcasts];
        
        _renderer = [[SyphonServerRendererMetal alloc] initWithDevice:_device pixelFormat:_pixelFormat];
    }
    return self;
}

- (void)setupIOSurfaceAndTextureForSize:(NSSize)size
{
    
    NSDictionary *surfaceAttributes = @{ (NSString *)kIOSurfaceIsGlobal: @YES,
                                         (NSString *)kIOSurfaceWidth: @(size.width),
                                         (NSString *)kIOSurfaceHeight: @(size.height),
                                         (NSString *)kIOSurfaceBytesPerElement: @4u };
    
    _surfaceRef =  IOSurfaceCreate((CFDictionaryRef) surfaceAttributes);
#warning MTO: for some reason, this causes a bad access. but it's there in SyphonServer OpenGL
//    [surfaceAttributes release];
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_pixelFormat
                                                                                    width:size.width
                                                                                   height:size.height
                                                                                mipmapped:NO];
    // MTLTextureUsageRenderTarget for user to draw into it
    // MTLtextureUsageShaderRead for user access on texture
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    _surfaceTexture = [_device newTextureWithDescriptor:desc iosurface:_surfaceRef plane:0];
    surfaceHasChanged = YES;
}


- (void) destroyIOSurfaceAndTexture
{
#if !SYPHON_DEBUG_NO_DRAWING
    if (_surfaceRef != NULL)
    {
        CFRelease(_surfaceRef);
        _surfaceRef = NULL;
    }
    _surfaceTexture = nil;
#endif // SYPHON_DEBUG_NO_DRAWING
}

- (void) setupSurfaceAndTextureForSize:(NSSize)size
{
    // Lazy loading
    if( _surfaceRef == NULL && _surfaceTexture == nil )
    {
        [self setupIOSurfaceAndTextureForSize:size];
    }
    
    // Check size change
    if( !NSEqualSizes(CGSizeMake(_surfaceTexture.width, _surfaceTexture.height), size) )
    {
        [self destroyIOSurfaceAndTexture];
        [self setupIOSurfaceAndTextureForSize:size];
    }
}

- (void) shutDownServer
{
    [self stopBroadcasts];
    if( _connectionManager )
    {
        [_connectionManager removeObserver:self forKeyPath:@"hasClients"];
        [_connectionManager stop];
        [_connectionManager release];
    }
    [self destroyIOSurfaceAndTexture];
}

- (void)dealloc
{
    [self shutDownServer];
    [_name release];
    [_uuid release];
    [super dealloc];
}

#pragma mark - Public API

- (void)drawFrame:(void(^)(id<MTLTexture> texture,id<MTLCommandBuffer> commandBuffer))block size:(NSSize)size commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    id<MTLTexture> texture = [self prepareToDrawFrameOfSize:size];
    if( texture != nil )
    {
        block(texture, commandBuffer);
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
#warning MTO : fix, texture is flipped on SyphonClient
            [self publishNewFrame];
        }];
    }
}

- (id<MTLTexture>)prepareToDrawFrameOfSize:(NSSize)size
{
    [self setupSurfaceAndTextureForSize:size];
    return [_surfaceTexture retain];
}

- (void)publishNewFrame
{
    if( surfaceHasChanged )
    {
        [_connectionManager setSurfaceID:IOSurfaceGetID(_surfaceRef)];
        surfaceHasChanged = NO;
    }
    [_connectionManager publishNewFrame];
}

- (id<MTLTexture>)newFrameTexture
{
    return [_surfaceTexture retain];
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish imageRegion:(NSRect)region flipped:(BOOL)isFlipped
{
    [self setupSurfaceAndTextureForSize:region.size];
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    [_renderer drawTexture:textureToPublish inTexture:_surfaceTexture withCommandBuffer:commandBuffer flipped:isFlipped];

// Possible alternative when texture should not be flipped. Probably faster. But user needs to change "framebufferOnly" parameter of its view to NO otherwise it'll crash
//        id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
//        blitCommandEncoder.label = @"Syphon blitCommandEncoder";
//        [blitCommandEncoder copyFromTexture:textureToPublish
//                                sourceSlice:0
//                                sourceLevel:0
//                               sourceOrigin:MTLOriginMake(region.origin.x, region.origin.y, 0)
//                                 sourceSize:MTLSizeMake(region.size.width, region.size.height, 1)
//                                  toTexture:_surfaceTexture
//                           destinationSlice:0
//                           destinationLevel:0
//                          destinationOrigin:MTLOriginMake(0, 0, 0)];
//
//        [blitCommandEncoder endEncoding];
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
        [self publishNewFrame];
    }];
    
    [commandBuffer commit];
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish flipped:(BOOL)isFlipped
{
    NSRect region = NSMakeRect(0, 0, textureToPublish.width, textureToPublish.height);
    [self publishFrameTexture:textureToPublish imageRegion:region flipped:isFlipped];
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish
{
    [self publishFrameTexture:textureToPublish flipped:NO];
}

- (NSString*)name
{
    OSSpinLockLock(&threadLock);
    NSString *result = [_name retain];
    OSSpinLockUnlock(&threadLock);
    return [result autorelease];
}

- (void)setName:(NSString *)newName
{
    [newName retain];
    OSSpinLockLock(&threadLock);
    [_name release];
    _name = newName;
    OSSpinLockUnlock(&threadLock);
    [_connectionManager setName:newName];
}

- (BOOL)hasClients
{
    return _connectionManager.hasClients;
}

- (void)stop
{
    [self shutDownServer];
}

#pragma mark - Private method

- (NSDictionary *)serverDescription
{
    NSDictionary *surface = _connectionManager.surfaceDescription;
    if( !surface )
    {
        surface = [NSDictionary dictionary];
    }
    
    // Getting the app name: helper tasks, command-line tools, etc, don't have a NSRunningApplication instance,
    // so fall back to NSProcessInfo in those cases, then use an empty string as a last resort.
    // http://developer.apple.com/library/mac/qa/qa1544/_index.html
    NSString *appName = [[NSRunningApplication currentApplication] localizedName];
    if( !appName )
    {
       appName = [[NSProcessInfo processInfo] processName];
    }
    if( !appName )
    {
        appName = [NSString string];
    }
    
    return @{ SyphonServerDescriptionDictionaryVersionKey: @kSyphonDictionaryVersion,
              SyphonServerDescriptionNameKey: _name,
              SyphonServerDescriptionUUIDKey: _uuid,
              SyphonServerDescriptionAppNameKey: appName,
              SyphonServerDescriptionSurfacesKey: @[ surface ] };
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"hasClients"])
    {
        if ([[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue] == YES)
        {
            [self willChangeValueForKey:keyPath];
        }
        else
        {
            [self didChangeValueForKey:keyPath];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Notification handling

- (void)startBroadcasts
{
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(handleDiscoveryRequest:)
                                                          name:SyphonServerAnnounceRequest
                                                        object:nil];
    [self postNotification:SyphonServerAnnounce];
}

- (void)stopBroadcasts
{
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [self postNotification:SyphonServerRetire];
}

- (void)handleDiscoveryRequest:(NSNotification *)aNotification
{
    [self postNotification:SyphonServerAnnounce];
}

- (void)postNotification:(NSString *)notificationName
{
    NSDictionary *description = self.serverDescription;
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:notificationName
                                                                 object:description[SyphonServerDescriptionUUIDKey]
                                                               userInfo:description
                                                     deliverImmediately:YES];
}

@end
