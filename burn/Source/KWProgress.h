/* KWProgress */

#import <Cocoa/Cocoa.h>
#import "NSNumber_Extensions.h"

@interface KWProgress : NSWindowController
{
    //Main outlets
    IBOutlet id progressBar;
    IBOutlet id progressIcon;
    IBOutlet id statusText;
    IBOutlet id taskText;
	IBOutlet id cancelProgress;
	
	//Variables
	NSArray *notificationNames;
	
	NSString *cancelNotification;
	id notifObject;
	NSImage *application;
	NSModalSession session;
}
//Main actions
- (IBAction)cancelProgress:(id)sender;
- (void)beginSheetForWindow:(NSWindow *)window;
- (void)beginWindow;
- (void)endSheet;
- (void)setTask:(NSString *)task;
- (void)setStatus:(NSString *)status;
- (void)setStatusByAddingPercent:(NSString *)percent;
- (void)setMaximumValue:(NSNumber *)number;
- (void)setValue:(NSNumber *)number;
- (void)setIcon:(NSImage *)image;
- (void)setCancelNotification:(NSString *)notification;
- (void)setCanCancel:(BOOL)cancel;

- (void)setIndeterminateOnMainThread:(NSNumber *)number;
- (void)setMaxiumValueOnMainThread:(NSNumber *)number;
- (void)setDoubleValueOnMainThread:(NSNumber *)number;
//- (void)setNotificationObject:(id)object;

@end
