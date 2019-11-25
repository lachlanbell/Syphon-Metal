#import <Cocoa/Cocoa.h>
#import <Syphon/Syphon.h>
#import "MetalImageView.h"

@interface SimpleClientAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
{
	SyphonMetalClient* syClient;
	IBOutlet NSArrayController *availableServersController;
	IBOutlet MetalImageView* metalView;
    NSArray *selectedServerDescriptions;
	NSTimeInterval fpsStart;
	NSUInteger fpsCount;
	NSUInteger FPS;
	NSUInteger frameWidth;
	NSUInteger frameHeight;
}
@property (readwrite, retain) NSArray *selectedServerDescriptions;
@property (readonly) NSString *status; // "frameWidth x frameHeight : FPS" or "--" if no server
@property (readwrite, assign) NSUInteger FPS;
@property (readwrite, assign) NSUInteger frameWidth;
@property (readwrite, assign) NSUInteger frameHeight;

@end
