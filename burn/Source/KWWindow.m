#import "KWWindow.h"
#import "KWTabViewItem.h"

@implementation KWWindow

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if ([self attachedSheet])
		return NO;

	KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
	id controller = [tabViewItem myController];
	
	if ([controller respondsToSelector:aSelector])
		return YES;
		
	return [super respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
	id controller = [tabViewItem myController];
	
	if ([controller respondsToSelector:selector])
		return [controller methodSignatureForSelector:selector];
		
	return [super methodSignatureForSelector: selector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	KWTabViewItem *tabViewItem = (KWTabViewItem *)[mainTabView selectedTabViewItem];
	id controller = [tabViewItem myController];
	SEL aSelector = [anInvocation selector];
	
	[controller performSelector:aSelector];
}

@end
