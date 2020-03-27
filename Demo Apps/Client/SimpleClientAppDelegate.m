#import "SimpleClientAppDelegate.h"

@interface SimpleClientAppDelegate (Private)
- (void)resizeWindowForCurrentVideo;
@end

@implementation SimpleClientAppDelegate

+ (NSSet *)keyPathsForValuesAffectingStatus
{
    return [NSSet setWithObjects:@"frameWidth", @"frameHeight", @"FPS", @"selectedServerDescriptions", nil];
}

- (void)dealloc
{
    [selectedServerDescriptions release];
    [super dealloc];
}

@synthesize FPS;
@synthesize frameWidth;
@synthesize frameHeight;

- (NSString *)status
{
    if (self.frameWidth && self.frameHeight)
    {
        return [NSString stringWithFormat:@"%lu x %lu : %lu FPS", (unsigned long)self.frameWidth, (unsigned long)self.frameHeight, (unsigned long)self.FPS];
    }
    else
    {
        return @"--";
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // We use an NSArrayController to populate the menu of available servers
    // Here we bind its content to SyphonServerDirectory's servers array
    [availableServersController bind:@"contentArray" toObject:[SyphonServerDirectory sharedDirectory] withKeyPath:@"servers" options:nil];
    
    // Slightly weird binding here, if anyone can neatly and non-weirdly improve on this then feel free...
    [self bind:@"selectedServerDescriptions" toObject:availableServersController withKeyPath:@"selectedObjects" options:nil];
    
    [[metalView window] setContentMinSize:(NSSize){400.0,300.0}];
	[[metalView window] setDelegate:self];
}

- (NSArray *)selectedServerDescriptions
{
    return selectedServerDescriptions;
}

- (void)setSelectedServerDescriptions:(NSArray *)descriptions
{
    if (![descriptions isEqualToArray:selectedServerDescriptions])
    {
        [descriptions retain];
        [selectedServerDescriptions release];
        selectedServerDescriptions = descriptions;
        // Stop our current client
        [syClient stop];
        [syClient release];
        // Reset our terrible FPS display
        fpsStart = [NSDate timeIntervalSinceReferenceDate];
        fpsCount = 0;
        self.FPS = 0;
        
        syClient = [[SyphonMetalClient alloc] initWithServerDescription:[descriptions lastObject] device:metalView.device options:nil frameHandler:^(SyphonMetalClient *client) {
            
            // This gets called whenever the client receives a new frame.
            
            // The new-frame handler could be called from any thread, but because we update our UI we have
            // to do this on the main thread.
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                
                if( !client.isValid )
                {
                    NSLog(@"client invalid");
                    return;
                }
                
                if( !client.hasNewFrame )
                {
                    NSLog(@"client said new frame boolean says otherwise");
                    return;
                }
                
                // First we track our framerate...
                fpsCount++;
                float elapsed = [NSDate timeIntervalSinceReferenceDate] - fpsStart;
                if (elapsed > 1.0)
                {
                    self.FPS = ceilf(fpsCount / elapsed);
                    fpsStart = [NSDate timeIntervalSinceReferenceDate];
                    fpsCount = 0;
                }
                // ...then we check to see if our dimensions display or window shape needs to be updated
                id<MTLTexture> frame = [client newFrameImage];
                
                NSSize imageSize = CGSizeMake(frame.width, frame.height);
                
                BOOL changed = NO;
                if (self.frameWidth != imageSize.width)
                {
                    changed = YES;
                    self.frameWidth = imageSize.width;
                }
                if (self.frameHeight != imageSize.height)
                {
                    changed = YES;
                    self.frameHeight = imageSize.height;
                }
                if (changed)
                {
                    [[metalView window] setContentAspectRatio:imageSize];
                    [self resizeWindowForCurrentVideo];
                }
                // ...then update the view and mark it as needing display
                metalView.image = frame;
                
                [metalView setNeedsDisplay:YES];
                
                // newFrameImage returns a retained image, always release it
                [frame release];
            }];
            
        }];

        // If we have a client we do nothing - wait until it outputs a frame
        // Otherwise clear the view
        if (syClient == nil)
        {
            metalView.image = nil;
            self.frameWidth = 0;
            self.frameHeight = 0;
            [metalView setNeedsDisplay:YES];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{		
	[syClient stop];
	[syClient release];
	syClient = nil;
}

#pragma mark Window Sizing

- (NSSize)windowContentSizeForCurrentVideo
{
	NSSize imageSize = NSMakeSize(self.frameWidth, self.frameHeight);
	
	if (imageSize.width == 0 || imageSize.height == 0)
	{
		imageSize.width = 640;
		imageSize.height = 480;
	}

    return imageSize;
}

- (NSRect)frameRectForContentSize:(NSSize)contentSize
{
    // Make sure we are at least as big as the window's minimum content size
	NSSize minContentSize = [[metalView window] contentMinSize];
	if (contentSize.height < minContentSize.height)
	{
		float scale = minContentSize.height / contentSize.height;
		contentSize.height *= scale;
		contentSize.width *= scale;
	}
	if (contentSize.width < minContentSize.width)
	{
		float scale = minContentSize.width / contentSize.width;
		contentSize.height *= scale;
		contentSize.width *= scale;
	}
    
    NSRect contentRect = (NSRect){[[metalView window] frame].origin, contentSize};
    NSRect frameRect = [[metalView window] frameRectForContentRect:contentRect];
    
    // Move the window up (or down) so it remains rooted at the top left
    float delta = [[metalView window] frame].size.height - frameRect.size.height;
    frameRect.origin.y += delta;
    
    // Attempt to remain on-screen
    NSRect available = [[[metalView window] screen] visibleFrame];
    if ((frameRect.origin.x + frameRect.size.width) > available.size.width)
    {
        frameRect.origin.x = available.size.width - frameRect.size.width;
    }
    if ((frameRect.origin.y + frameRect.size.height) > available.size.height)
    {
        frameRect.origin.y = available.size.height - frameRect.size.height;
    }
    return frameRect;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
	// We get this when the user hits the zoom box, if we're not already zoomed
	if ([window isEqual:[metalView window]])
	{
		// Resize to the current video dimensions
        return [self frameRectForContentSize:[self windowContentSizeForCurrentVideo]];        
    }
	else
	{
		return newFrame;
	}
}

- (void)resizeWindowForCurrentVideo
{
    // Resize to the correct aspect ratio, keeping as close as possible to our current dimensions
    NSSize wantedContentSize = [self windowContentSizeForCurrentVideo];
    NSSize currentSize = [[[metalView window] contentView] frame].size;
    float wr = wantedContentSize.width / currentSize.width;
    float hr = wantedContentSize.height / currentSize.height;
    NSUInteger widthScaledToHeight = wantedContentSize.width / hr;
    NSUInteger heightScaledToWidth = wantedContentSize.height / wr;
    if (widthScaledToHeight - currentSize.width < heightScaledToWidth - currentSize.height)
    {
        wantedContentSize.width /= hr;
        wantedContentSize.height /= hr;
    }
    else
    {
        wantedContentSize.width /= wr;
        wantedContentSize.height /= wr;        
    }
    
    NSRect newFrame = [self frameRectForContentSize:wantedContentSize];
    [[metalView window] setFrame:newFrame display:YES animate:NO];
}

@end
