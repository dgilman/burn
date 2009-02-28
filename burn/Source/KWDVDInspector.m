#import "KWDVDInspector.h"
#import "videoController.h"
#import <KWConverter.h>
#import "KWCommonMethods.h"

@interface NSSliderCell (isPressed)
- (BOOL)isPressed;
@end

@implementation NSSliderCell (isPressed)
- (BOOL)isPressed
{
return _scFlags.isPressed;
}
@end

@implementation KWDVDInspector

- (id) init
{
self = [super init];

tableData = [[NSMutableArray alloc] init];

return self;
}

- (void)dealloc
{
[tableData release];

[super dealloc];
}

- (void)updateView:(id)object
{
currentTableView = object;
currentObject = [[(videoController *)[object dataSource] myDataSource] objectAtIndex:[object selectedRow]];

[nameField setStringValue:[currentObject objectForKey:@"Name"]];
[timeField setStringValue:[currentObject objectForKey:@"Size"]];
[iconView setImage:[currentObject objectForKey:@"Icon"]];

KWConverter *converter = [[KWConverter alloc] init];
[timeSlider setMaxValue:(double)[converter totalTimeInSeconds:[currentObject objectForKey:@"Path"]]];
[timeSlider setDoubleValue:0];
[converter release];

[tableData removeAllObjects];
	
	if ([currentObject objectForKey:@"Chapters"])
	tableData = [[currentObject objectForKey:@"Chapters"] mutableCopy];

[tableView reloadData];

[previewView setImage:nil];
}

- (IBAction)add:(id)sender
{
[previewView setImage:[[KWConverter alloc] getImageAtPath:[currentObject objectForKey:@"Path"] atTime:0 isWideScreen:[[currentObject objectForKey:@"WideScreen"] boolValue]]];	
[titleField setStringValue:@""];
[NSApp beginSheet:chapterSheet modalForWindow:[myView window] modalDelegate:self didEndSelector:@selector(endChapterSheet) contextInfo:nil];
}

- (void)endChapterSheet
{
[chapterSheet orderOut:self];
}

- (IBAction)addSheet:(id)sender
{
NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

[rowData setObject:[KWCommonMethods formatTime:(int)[timeSlider doubleValue]] forKey:@"Time"];
[rowData setObject:[titleField stringValue] forKey:@"Title"];
[rowData setObject:[NSNumber numberWithDouble:[timeSlider doubleValue]] forKey:@"RealTime"];
[rowData setObject:[[previewView image] TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0] forKey:@"Image"];

[tableData addObject:[rowData copy]];

NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Time" ascending:YES];
[tableData sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
[sortDescriptor release];

NSMutableDictionary *tempDict = [currentObject mutableCopy];
[tempDict setObject:[tableData copy] forKey:@"Chapters"];
[[(videoController *)[currentTableView dataSource] myDataSource] replaceObjectAtIndex:[currentTableView selectedRow] withObject:[tempDict copy]];
[currentTableView reloadData];
currentObject = [[(videoController *)[currentTableView dataSource] myDataSource] objectAtIndex:[currentTableView selectedRow]];

[tableView reloadData];
}

- (IBAction)cancelSheet:(id)sender
{
[NSApp endSheet:chapterSheet];
}

- (IBAction)remove:(id)sender
{
id myObject;

	// get and sort enumerator in descending order
	NSEnumerator *selectedItemsEnum = [[[[tableView selectedRowEnumerator] allObjects]
			sortedArrayUsingSelector:@selector(compare:)] reverseObjectEnumerator];
	
	// remove object in descending order
	myObject = [selectedItemsEnum nextObject];
	while (myObject) {
		[tableData removeObjectAtIndex:[myObject intValue]];
		myObject = [selectedItemsEnum nextObject];
	}
	
NSMutableDictionary *tempDict = [currentObject mutableCopy];
[tempDict setObject:[tableData copy] forKey:@"Chapters"];
[[(videoController *)[currentTableView dataSource] myDataSource] replaceObjectAtIndex:[currentTableView selectedRow] withObject:[tempDict copy]];

[tableView deselectAll:nil];
[tableView reloadData];
}

- (IBAction)timeSlider:(id)sender
{
[previewView setImage:[[KWConverter alloc] getImageAtPath:[currentObject objectForKey:@"Path"] atTime:(int)[timeSlider doubleValue] isWideScreen:[[currentObject objectForKey:@"WideScreen"] boolValue]]];

[currentTimeField setStringValue:[KWCommonMethods formatTime:(int)[timeSlider doubleValue]]];
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row
{    return NO; }

- (int) numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tableData count];
}

- (id) tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
    row:(int)row
{
    NSDictionary *rowData = [tableData objectAtIndex:row];
    return [rowData objectForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)anObject
    forTableColumn:(NSTableColumn *)tableColumn
    row:(int)row
{
NSMutableDictionary *rowData = [tableData objectAtIndex:row];
[rowData setObject:anObject forKey:[tableColumn identifier]];
}

- (id)myView
{
return myView;
}

@end
