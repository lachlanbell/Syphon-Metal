#import "SyphonMetalClient.h"
#import "SyphonServerDirectory.h"
#import "SyphonPrivate.h"
#import "SyphonClientConnectionManager.h"


#import <libkern/OSAtomic.h>

@implementation SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME

static void *SyphonClientServersContext = &SyphonClientServersContext;

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
    if ([theKey isEqualToString:@"serverDescription"])
    {
        return NO;
    }
    else
    {
        return [super automaticallyNotifiesObserversForKey:theKey];
    }
}

#if SYPHON_DEBUG_NO_DRAWING
+ (void)load
{
    NSLog(@"SYPHON FRAMEWORK: DRAWING IS DISABLED");
    [super load];
}
#endif

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (id)initWithServerDescription:(NSDictionary *)description device:(id<MTLDevice>)theDevice colorPixelFormat:(MTLPixelFormat)theColorPixelFormat options:(NSDictionary *)options
                newFrameHandler:(void (^)(SYPHON_METAL_CLIENT_UNIQUE_CLASS_NAME *client))handler
{
    self = [super init];
    if (self)
    {
        colorPixelFormat = theColorPixelFormat;
        device = theDevice;
        _status = 1;
        
        _connectionManager = [[SyphonClientConnectionManager alloc] initWithServerDescription:description];
        _handler = [handler copy]; // copy don't retain
        _lock = OS_SPINLOCK_INIT;
        _serverDescription = [description retain];
        
        [[SyphonServerDirectory sharedDirectory] addObserver:self
                                                  forKeyPath:@"servers"
                                                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                                                     context:SyphonClientServersContext];
        
        NSNumber *dictionaryVersion = [description objectForKey:SyphonServerDescriptionDictionaryVersionKey];
        if (dictionaryVersion == nil
            || [dictionaryVersion unsignedIntValue] > kSyphonDictionaryVersion
            || _connectionManager == nil)
        {
            [self release];
            return nil;
        }
        
        [(SyphonClientConnectionManager *)_connectionManager addInfoClient:(id <SyphonInfoReceiving>)self
                                                             isFrameClient:handler != nil ? YES : NO];
    }
    return self;
}

- (void) dealloc
{
    [[SyphonServerDirectory sharedDirectory] removeObserver:self forKeyPath:@"servers"];
    [self stop];
    [_handler release];
    [_serverDescription release];
    [super dealloc];
}

- (void)stop
{
    OSSpinLockLock(&_lock);
    if (_status == 1)
    {
        [(SyphonClientConnectionManager *)_connectionManager removeInfoClient:(id <SyphonInfoReceiving>)self
                                                                isFrameClient:_handler != nil ? YES : NO];
        [(SyphonClientConnectionManager *)_connectionManager release];
        _connectionManager = nil;
        _status = 0;
    }
    _frame = nil;
    _frameValid = NO;
    OSSpinLockUnlock(&_lock);
}

- (BOOL)isValid
{
    OSSpinLockLock(&_lock);
    BOOL result = ((SyphonClientConnectionManager *)_connectionManager).isValid;
    OSSpinLockUnlock(&_lock);
    return result;
}

- (void)receiveNewFrame
{
    if (_handler)
    {
        _handler(self);
    }
}

- (void)invalidateFrame
{
    /*
     Because releasing a SyphonImage causes a glDelete we postpone deletion until we can do work in the context
     DO NOT take the lock here, it may already be locked and waiting for the SyphonClientConnectionManager lock
     */
    OSAtomicTestAndClearBarrier(0, &_frameValid);
}

#pragma mark Rendering frames
- (BOOL)hasNewFrame
{
    BOOL result;
    OSSpinLockLock(&_lock);
    result = _lastFrameID != ((SyphonClientConnectionManager *)_connectionManager).frameID;
    OSSpinLockUnlock(&_lock);
    return result;
}

- (id<MTLTexture>)newFrameImage
{
    OSSpinLockLock(&_lock);
    _lastFrameID = [(SyphonClientConnectionManager *)_connectionManager frameID];
    if (_frameValid == 0)
    {
        [_frame release];
        _frame = [(SyphonClientConnectionManager *)_connectionManager newMetalTextureForDevice:device colorPixelFormat:colorPixelFormat];
        OSAtomicTestAndSetBarrier(0, &_frameValid);
    }
    OSSpinLockUnlock(&_lock);
    return [_frame retain];
}

- (NSDictionary *)serverDescription
{
    OSSpinLockLock(&_lock);
    NSDictionary *description = _serverDescription;
    OSSpinLockUnlock(&_lock);
    return description;
}

#pragma mark Changes
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (context == SyphonClientServersContext)
    {
        NSUInteger kind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
        if (kind == NSKeyValueChangeSetting || kind == NSKeyValueChangeReplacement)
        {
            NSArray *servers = change[NSKeyValueChangeNewKey];
            NSString *uuid = _serverDescription[SyphonServerDescriptionUUIDKey];
            for (NSDictionary *description in servers) {
                if ([description[SyphonServerDescriptionUUIDKey] isEqualToString:uuid] &&
                    ![_serverDescription isEqualToDictionary:description])
                {
                    [self willChangeValueForKey:@"serverDescription"];
                    description = [description copy];
                    OSSpinLockLock(&_lock);
                    [_serverDescription release];
                    _serverDescription = description;
                    OSSpinLockUnlock(&_lock);
                    [self didChangeValueForKey:@"serverDescription"];
                }
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
@end

