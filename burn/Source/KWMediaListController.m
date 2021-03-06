//
//  KWMediaListController.m
//  Burn
//
//  Created by Maarten Foukhar on 13-09-09.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#import "KWMediaListController.h"
#import "KWCommonMethods.h"
#import "KWDiscCreator.h"

@implementation KWMediaListController

- (id)init
{
	self = [super init];
	
	//Known protected files can't be converted
	knownProtectedFiles = [[NSArray alloc] initWithObjects:@"m4p", @"m4b", NSFileTypeForHFSTypeCode('M4P '), NSFileTypeForHFSTypeCode('M4B '), nil];
	
	temporaryFiles = [[NSMutableArray alloc] init];
	
	//Set a starting row for dropping files in the list
	currentDropRow = -1;
	
	return self;
}

- (void)dealloc
{
	//Stop listening to notifications from the default notification center
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[knownProtectedFiles release];
	knownProtectedFiles = nil;
	
	[temporaryFiles release];
	temporaryFiles = nil;

	[super dealloc];
}

- (void)awakeFromNib
{
	//Notifications
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	//Used to save the popups when the user selects this option in the preferences
	[defaultCenter addObserver:self selector:@selector(saveTableViewPopup:) name:@"KWTogglePopups" object:nil];
	//Prevent files to be dropped when for example a sheet is open
	[defaultCenter addObserver:self selector:@selector(setTableViewState:) name:@"KWSetDropState" object:nil];
	//Updates the Inspector window with the new item selected in the list
	[defaultCenter addObserver:self selector:@selector(tableViewSelectionDidChange:) name:@"KWListSelected" object:tableView];
	//Updates the Inspector window to show the information about the disc
	[defaultCenter addObserver:self selector:@selector(volumeLabelSelected:) name:@"KWDiscNameSelected" object:discName];

	//How should our tableview update its sizes when adding and modifying files
	[tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

	//The user can drag files into the tableview (including iMovie files)
	[tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, @"NSGeneralPboardType", @"CorePasteboardFlavorType 0x6974756E", nil]];
}

//////////////////
// Main actions //
//////////////////

#pragma mark -
#pragma mark •• Main actions

//Show a open panel to add files
- (IBAction)openFiles:(id)sender
{
	NSOpenPanel *sheet = [NSOpenPanel openPanel];
	[sheet setCanChooseFiles:YES];
	[sheet setCanChooseDirectories:YES];
	[sheet setAllowsMultipleSelection:YES];
	
	[sheet beginSheetForDirectory:nil file:nil types:allowedFileTypes modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

//Check all files
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton)
		[self checkFiles:[sheet filenames]];
}

//Delete the selected row(s)
- (IBAction)deleteFiles:(id)sender
{	
	//Remove rows
	NSArray *selectedObjects = [KWCommonMethods allSelectedItemsInTableView:tableView fromArray:tableData];
	[tableData removeObjectsInArray:selectedObjects];
	
	//Update the tableview
	[tableView deselectAll:nil];
	[tableView reloadData];
	
	//Reset the total size
	[self setTotal];
}

//Bogusmethod used in subclass
- (void)addFile:(id)file isSelfEncoded:(BOOL)selfEncoded{}

//Add a DVD-Folder and delete the rest
- (void)addDVDFolder:(NSString *)path
{
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];
	[rowData setObject:[[NSFileManager defaultManager] displayNameAtPath:path] forKey:@"Name"];
	[rowData setObject:path forKey:@"Path"];
	[rowData setObject:[KWCommonMethods makeSizeFromFloat:[KWCommonMethods calculateRealFolderSize:path] * 2048] forKey:@"Size"];
	[rowData setObject:[[[NSWorkspace sharedWorkspace] iconForFile:path] retain] forKey:@"Icon"];

	[tableData removeAllObjects];
	[tableData addObject:rowData];
	[tableView reloadData];
}

//Check files in a seperate thread
- (void)checkFiles:(NSArray *)paths
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setCancelAdding) name:@"cancelAdding" object:nil];

	cancelAddingFiles = NO;

	progressPanel = [[KWProgress alloc] init];
	[progressPanel setTask:NSLocalizedString(@"Checking files...", nil)];
	[progressPanel setStatus:NSLocalizedString(@"Scanning for files and folders", nil)];
	[progressPanel setIcon:[NSImage imageNamed:@"Burn"]];
	[progressPanel setMaximumValue:[NSNumber numberWithDouble:0]];
	[progressPanel setCancelNotification:@"cancelAdding"];
	[progressPanel beginSheetForWindow:mainWindow];

	[NSThread detachNewThreadSelector:@selector(checkFilesInThread:) toTarget:self withObject:paths];
}

//Set our BOOL to stop the checking thread
- (void)setCancelAdding
{
	cancelAddingFiles = YES;
}

//Check if it is QuickTime protected file
- (BOOL)isProtected:(NSString *)path
{
	return ([knownProtectedFiles containsObject:[[path pathExtension] lowercaseString]] | [knownProtectedFiles containsObject:NSFileTypeForHFSTypeCode([[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue])]);
}

//Check if the file is folder or file, if it is folder scan it, when a file
//if it is a correct file
- (void)checkFilesInThread:(NSArray *)paths
{
	//Needed because we're in a new thread
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSString *firstFile = [paths objectAtIndex:0];
	NSInteger numberOfPaths = [paths count];
	
	protectedFiles = [[NSMutableArray alloc] init];
	
	if (numberOfPaths == 1 && [[[firstFile lastPathComponent] lowercaseString] isEqualTo:[dvdFolderName lowercaseString]] && isDVD)
	{
		[self addDVDFolder:firstFile];
	}
	else if ([paths count] == 1 && [defaultManager fileExistsAtPath:[firstFile stringByAppendingPathComponent:dvdFolderName]] && isDVD)
	{
		[self addDVDFolder:[firstFile stringByAppendingPathComponent:dvdFolderName]];
		[discName setStringValue:[firstFile lastPathComponent]];
	}
	else
	{
		NSMutableArray *files = [NSMutableArray array];
		//Needed for 10.5 and lower (the Finder messes up orders)
		NSArray *sortedPaths = [paths sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	
		NSInteger i;
		for (i = 0; i < [sortedPaths count]; i ++)
		{
			NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
			
			if (cancelAddingFiles == YES)
				break;
			
			NSDirectoryEnumerator *enumer;
			NSString* pathName;
			NSString *realPath = [self getRealPath:[sortedPaths objectAtIndex:i]];
			BOOL fileIsFolder = NO;
			
			[defaultManager fileExistsAtPath:realPath isDirectory:&fileIsFolder];

			if (fileIsFolder)
			{
				enumer = [defaultManager enumeratorAtPath:realPath];
				while (pathName = [enumer nextObject])
				{
					NSAutoreleasePool *subPool = [[NSAutoreleasePool alloc] init];
						
					if (cancelAddingFiles == YES)
						break;
						
					NSString *realPathName = [self getRealPath:[realPath stringByAppendingPathComponent:pathName]];
			
					if (![self isProtected:realPathName])
					{
						NSString *hfsType = NSFileTypeForHFSTypeCode([[[defaultManager fileAttributesAtPath:realPathName traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);
							
						if ([allowedFileTypes containsObject:[[realPathName pathExtension] lowercaseString]] | [allowedFileTypes containsObject:hfsType])
							[files addObject:realPathName];
							//[self performSelectorOnMainThread:@selector(addFile:isSelfEncoded:) withObject:realPathName waitUntilDone:YES];
					}
					else
					{
						[protectedFiles addObject:realPathName];
					}
				
					[subPool release];
					subPool = nil;
				}
			}
			else
			{
				if (cancelAddingFiles == YES)
					break;
						
				if (![self isProtected:realPath])
				{
					NSString *hfsType = NSFileTypeForHFSTypeCode([[[defaultManager fileAttributesAtPath:realPath traverseLink:YES] objectForKey:NSFileHFSTypeCode] longValue]);
							
					if ([allowedFileTypes containsObject:[[realPath pathExtension] lowercaseString]] | [allowedFileTypes containsObject:hfsType])
						[files addObject:realPath];
						//[self performSelectorOnMainThread:@selector(addFile:isSelfEncoded:) withObject:realPath waitUntilDone:YES];
				}
				else
				{
					[protectedFiles addObject:realPath];
				}
			}
	
			[subPool release];
			subPool = nil;
		}
		
		NSInteger numberOfFiles = [files count];
		BOOL audioCD = [currentFileSystem isEqualTo:@"-audio-cd"];
			
		if (audioCD)
			[progressPanel setMaximumValue:[NSNumber numberWithInteger:numberOfFiles]];
			
		for (i = 0; i < [files count]; i ++)
		{
			if (cancelAddingFiles == YES)
				break;
				
			NSAutoreleasePool *subpool = [[NSAutoreleasePool alloc] init];
				
			NSString *file = [files objectAtIndex:i];
				
			if (audioCD)
			{
				NSString *fileName = [defaultManager displayNameAtPath:file];
				[progressPanel setStatus:[NSString stringWithFormat:NSLocalizedString(@"Processing: %@ (%i of %i)", nil), fileName, i + 1, numberOfFiles]];
			}
				
			[self addFile:file isSelfEncoded:NO];
				
			if (audioCD)
				[progressPanel setValue:[NSNumber numberWithInteger:i + 1]];
				
			[subpool release];
			subpool = nil;
		}
	}
	
	cancelAddingFiles = NO;
	currentDropRow = -1;

	[progressPanel endSheet];
	[progressPanel release];
	progressPanel = nil;

	//Stop being the observer
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"cancelAdding" object:nil];

	[self performSelectorOnMainThread:@selector(showAlert) withObject:nil waitUntilDone:NO];

	[pool release];
	pool = nil;
}

/////////////////////////
// Option menu actions //
/////////////////////////

#pragma mark -
#pragma mark •• Option menu actions

//Setup options menu and open the right popup
- (IBAction)accessOptions:(id)sender
{	
	//Setup options menus
	NSInteger i;
	for (i = 0; i < [optionsPopup numberOfItems] - 1; i ++)
	{
		[[optionsPopup itemAtIndex:i + 1] setState:[[[NSUserDefaults standardUserDefaults] objectForKey:[optionsMappings objectAtIndex:i]] integerValue]];
	}

	[optionsPopup performClick:self];
}

//Set option in the preferences
- (IBAction)setOption:(id)sender
{
	NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
	[standardDefaults setBool:([sender state] == NSOffState) forKey:[optionsMappings objectAtIndex:[optionsPopup indexOfItem:sender] - 1]];
	[standardDefaults synchronize];
}

/////////////////////
// Convert actions //
/////////////////////

#pragma mark -
#pragma mark •• Convert actions

//Convert files to path
- (void)convertFiles:(NSString *)path
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSMutableArray *filePaths = [NSMutableArray array];

	NSInteger i;
	for (i = 0; i < [incompatibleFiles count]; i ++)
	{
		[filePaths addObject:[[incompatibleFiles objectAtIndex:i] objectForKey:@"Path"]];
	}

	[incompatibleFiles release];
	incompatibleFiles = nil;

	converter = [[KWConverter alloc] init];
	
	NSDictionary *options = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:path, convertExtension, [[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultRegion"], [NSNumber numberWithInteger:convertKind], nil]  forKeys:[NSArray arrayWithObjects:@"KWConvertDestination", @"KWConvertExtension", @"KWConvertRegion", @"KWConvertKind", nil]];
	NSString *errorString;
	
	NSInteger result = [converter batchConvert:filePaths withOptions:options errorString:&errorString];

	NSArray *succeededFiles = [NSArray arrayWithArray:[converter succesArray]];
	
	[converter release];
	converter = nil;

	for (i = 0; i < [succeededFiles count]; i ++)
	{
		[self addFile:[succeededFiles objectAtIndex:i] isSelfEncoded:YES];
	}

	[progressPanel endSheet];
	[progressPanel release];
	progressPanel = nil;

	if (result == 0)
	{
		NSString *finishMessage;
	
		if ([filePaths count] > 1)
			finishMessage = [NSString stringWithFormat:NSLocalizedString(@"Finished converting %ld files", nil), (long)[filePaths count]];
		else
			finishMessage = NSLocalizedString(@"Finished converting 1 file", nil);
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"growlFinishedConverting" object:finishMessage];
	}
	else if (result == 1)
	{
		[self performSelectorOnMainThread:@selector(showConvertFailAlert:) withObject:errorString waitUntilDone:YES];
	}

	[pool release];
	pool = nil;
}

//Show an alert if needed (protected or no default files
- (void)showAlert
{
	if ([incompatibleFiles count] > 0)
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Convert", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
		[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
		
		NSString *convertString;
		NSString *protectedString = @"";
		
		if ([protectedFiles count] > 1)
		{
			protectedString = NSLocalizedString(@"\n(Note: there are a few protected mp4 files which can't be converted)", nil);
		}
		else if ([protectedFiles count] > 0)
		{
			protectedString = NSLocalizedString(@"\n(Note: there is a protected mp4 file which can't be converted)", nil);
		}
		
		if ([incompatibleFiles count] > 1)
		{
			[alert setMessageText:NSLocalizedString(@"Some incompatible files", nil)];
			convertString = [NSString stringWithFormat:NSLocalizedString(@"Would you like to convert those files to %@?%@", nil),convertExtension,protectedString];
		}
		else
		{
			[alert setMessageText:NSLocalizedString(@"One incompatible file", nil)];
			convertString = [NSString stringWithFormat:NSLocalizedString(@"Would you like to convert that file to %@?%@", nil),convertExtension,protectedString];
		}
		
		[alert setInformativeText:convertString];
		
		[protectedFiles removeAllObjects];
		[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else if ([protectedFiles count] > 0)
	{
		NSString *message;
		NSString *information;
			
		if ([protectedFiles count] > 1)
		{
			message = NSLocalizedString(@"Some protected mp4 files", nil);
			information = NSLocalizedString(@"These files can't be converted", nil);
		}
		else
		{
			message = NSLocalizedString(@"One protected mp4 file", nil);
			information = NSLocalizedString(@"This file can't be converted", nil);
		}
		
		[KWCommonMethods standardAlertWithMessageText:message withInformationText:information withParentWindow:mainWindow];
	}
	
	[protectedFiles release];
	protectedFiles = nil;
}

//Alert did end, whe don't need to do anything special, well releasing the alert we do, the user should
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:self];
	
	if (returnCode == NSAlertFirstButtonReturn) 
	{
		NSOpenPanel *sheet = [NSOpenPanel openPanel];
		[sheet setCanChooseFiles: NO];
		[sheet setCanChooseDirectories: YES];
		[sheet setAllowsMultipleSelection: NO];
		[sheet setCanCreateDirectories: YES];
		[sheet setPrompt:NSLocalizedString(@"Choose", nil)];
		[sheet setMessage:[NSString stringWithFormat:NSLocalizedString(@"Choose a location to save the %@ files", nil),convertExtension]];
		
			if (useRegion)
			{
				[regionPopup selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] objectForKey:@"KWDefaultRegion"] integerValue]];
				[sheet setAccessoryView:saveView];
			}
		
		[sheet beginSheetForDirectory:nil file:nil types:nil modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	else
	{
		[incompatibleFiles release];
		incompatibleFiles = nil;
	}
}

//Place has been chosen change our editfield with this path
- (void)savePanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
		if (useRegion)
			[[NSUserDefaults standardUserDefaults] setObject:[regionPopup objectValue] forKey:@"KWDefaultRegion"];
	
		progressPanel = [[KWProgress alloc] init];
		[progressPanel setTask:NSLocalizedString(@"Preparing to encode", nil)];
		[progressPanel setStatus:NSLocalizedString(@"Checking file...", nil)];
		[progressPanel setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:convertExtension]];
		[progressPanel setMaximumValue:[NSNumber numberWithInteger:100 * [incompatibleFiles count]]];
		[progressPanel beginSheetForWindow:mainWindow];
	
		[NSThread detachNewThreadSelector:@selector(convertFiles:) toTarget:self withObject:[sheet filename]];
	}
	else
	{
		[incompatibleFiles release];
		incompatibleFiles = nil;
	}
}

//Show an alert if some files failed to be converted
- (void)showConvertFailAlert:(NSString *)errorString
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
		
	if ([errorString rangeOfString:@"\n"].length > 0)
		[alert setMessageText:NSLocalizedString(@"Burn failed to encode some files", nil)];
	else
		[alert setMessageText:NSLocalizedString(@"Burn failed to encode one file", nil)];

	[alert setInformativeText:errorString];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	[alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

///////////////////////////
// Disc creation actions //
///////////////////////////

#pragma mark -
#pragma mark •• Disc creation actions

//Burn the disc
- (void)burn:(id)sender
{
	[myDiscCreationController burnDiscWithName:[discName stringValue] withType:currentType];
}

//Save a image
- (void)saveImage:(id)sender
{
	[myDiscCreationController saveImageWithName:[discName stringValue] withType:currentType withFileSystem:currentFileSystem];
}

//Bogusmethod used in subclass
- (id)myTrackWithBurner:(KWBurner *)burner errorString:(NSString **)error
{
	return nil;
}

//////////////////
// Save actions //
//////////////////

#pragma mark -
#pragma mark •• Save actions

//Open .burn document
- (void)openBurnDocument:(NSString *)path
{	
	NSDictionary *burnDocument = [NSDictionary dictionaryWithContentsOfFile:path];

	[tableViewPopup setObjectValue:[burnDocument objectForKey:@"KWSubType"]];

	NSDictionary *savedDictionary = [burnDocument objectForKey:@"KWProperties"];
	NSArray *savedArray = [savedDictionary objectForKey:@"Files"];
	
	[self tableViewPopup:self];
	NSMutableDictionary *rowData = [NSMutableDictionary dictionary];

	[tableData removeAllObjects];

		NSInteger i;
		for (i = 0; i < [savedArray count]; i ++)
		{
			NSDictionary *currentDictionary = [savedArray objectAtIndex:i];
			NSString *path = [currentDictionary objectForKey:@"Path"];

			if ([[NSFileManager defaultManager] fileExistsAtPath:path])
			{
				[rowData addEntriesFromDictionary:currentDictionary];
				[rowData setObject:[[NSWorkspace sharedWorkspace] iconForFile:path] forKey:@"Icon"];
				[tableData addObject:[NSDictionary dictionaryWithDictionary:rowData]];
				[rowData removeAllObjects];
			}
		}
		
	[tableView reloadData];
	
	[self setTotal];

	[discName setStringValue:[savedDictionary objectForKey:@"Name"]];
	
	NSDictionary *extraInformation = [burnDocument objectForKey:@"KWExtraInformation"];
	
	if (extraInformation)
		[self setExtraInformation:extraInformation];
	
	[self sortIfNeeded];
}

- (void)setExtraInformation:(NSDictionary *)information{}

//Save .burn document
- (void)saveDocument:(id)sender
{
	NSSavePanel *sheet = [NSSavePanel savePanel];
	[sheet setRequiredFileType:@"burn"];
	[sheet setCanSelectHiddenExtension:YES];
	[sheet setMessage:NSLocalizedString(@"Choose a location to save the burn file", nil)];
	[sheet beginSheetForDirectory:nil file:[[discName stringValue] stringByAppendingPathExtension:@"burn"] modalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(saveDocumentPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)saveDocumentPanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == NSOKButton) 
	{
		NSMutableArray *tempArray = [NSMutableArray arrayWithArray:tableData];
		NSMutableDictionary *tempDict;
	
		NSInteger i;
		for (i = 0; i < [tempArray count]; i ++)
		{
			NSMutableDictionary *currentDict = [tempArray objectAtIndex:i];
			tempDict = [NSMutableDictionary dictionaryWithDictionary:currentDict];
			[tempDict removeObjectForKey:@"Icon"];
			[tempArray replaceObjectAtIndex:i withObject:tempDict];
		}
	
		NSDictionary *burnFileProperties = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:tempArray, [discName stringValue], nil] forKeys:[NSArray arrayWithObjects:@"Files", @"Name", nil]];
		
		NSInteger type = currentType;
		
			if (currentType == 4)
			type = 2;
		
		NSMutableDictionary *burnFile = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInteger:type], [NSNumber numberWithInteger:[tableViewPopup indexOfSelectedItem]], burnFileProperties, nil] forKeys:[NSArray arrayWithObjects:@"KWType", @"KWSubType", @"KWProperties", nil]];
		
		NSDictionary *extraInformation = [self extraInformation];
		
		if (extraInformation)
			[burnFile setObject:extraInformation forKey:@"KWExtraInformation"];
		
		NSString *errorString;
		
		if ([KWCommonMethods writeDictionary:burnFile toFile:[sheet filename] errorString:&errorString])
		{	
			if ([sheet isExtensionHidden])
				[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"NSFileExtensionHidden"] atPath:[sheet filename]];
		}
		else
		{
			[KWCommonMethods standardAlertWithMessageText:NSLocalizedString(@"Failed to save Burn file",nil) withInformationText:errorString withParentWindow:mainWindow];
		}
	}
}

- (NSDictionary *)extraInformation
{
	return nil;
}

///////////////////////
// Tableview actions //
///////////////////////

#pragma mark -
#pragma mark •• Tableview actions

//Popup clicked
- (IBAction)tableViewPopup:(id)sender{}

- (void)saveTableViewPopup:(id)sender{}

- (void)sortIfNeeded{}

- (void)setTableViewState:(NSNotification *)notif
{
	if ([[notif object] boolValue] == YES)
		[tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, @"NSGeneralPboardType", @"CorePasteboardFlavorType 0x6974756E", nil]];
	else
		[tableView unregisterDraggedTypes];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{    
	return NO; 
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
	NSInteger result = NSDragOperationNone;

    if (op == NSTableViewDropAbove && canBeReorderd)
	{
		result = NSDragOperationMove;
	}
	else
	{
		[tv setDropRow:[tv numberOfRows] dropOperation:NSTableViewDropAbove];
		result = NSTableViewDropAbove;
	}

	return (result);
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op
{
	NSPasteboard *pboard = [info draggingPasteboard];

	if ([[pboard types] containsObject:@"NSGeneralPboardType"] && canBeReorderd)
	{
		NSArray *draggedRows = [pboard propertyListForType:@"KWDraggedRows"];
		NSMutableArray *draggedObjects = [NSMutableArray array];
		NSInteger numberOfRows = [tableData count];
		
		NSInteger i;
		for (i = 0; i < [draggedRows count]; i ++)
		{
			NSInteger currentRow = [[draggedRows objectAtIndex:i] integerValue];
			[draggedObjects addObject:[tableData objectAtIndex:currentRow]];
			[tableData removeObjectAtIndex:currentRow];
		}
		
		BOOL shouldSelectRow = ([draggedRows count] > 1 | [tableView isRowSelected:[[draggedRows objectAtIndex:0] integerValue]]);
		
		[tableView deselectAll:nil];
		
		for (i = 0; i < [draggedObjects count]; i ++)
		{
			id object = [draggedObjects objectAtIndex:i];
			NSInteger destinationRow = row + i;
			
			if (row > numberOfRows)
			{
				[tableData addObject:object];
			
				destinationRow = [tableData count] - 1;
			}
			else
			{
				if ([[draggedRows objectAtIndex:i] integerValue] < destinationRow)
					destinationRow = destinationRow - [draggedRows count];
				
				[tableData insertObject:object atIndex:destinationRow];
			}
			
			if (shouldSelectRow)
				[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:YES];
		}
	
		[tableView reloadData];
	}
	else if ([[pboard types] containsObject:@"CorePasteboardFlavorType 0x6974756E"])
	{
		NSArray *keys = [[[pboard propertyListForType:@"CorePasteboardFlavorType 0x6974756E"] objectForKey:@"Tracks"] allKeys];
		NSMutableArray *fileList = [NSMutableArray array];
	
		NSInteger i;
		for (i = 0; i < [keys count]; i ++)
		{
			NSURL *url = [[NSURL alloc] initWithString:[[[[pboard propertyListForType:@"CorePasteboardFlavorType 0x6974756E"] objectForKey:@"Tracks"] objectForKey:[keys objectAtIndex:i]] objectForKey:@"Location"]];
			[fileList addObject:[url path]];
			[url release];
			url = nil;
		}
		
		[self checkFiles:fileList];
	}
	else
	{
		if (canBeReorderd)
		currentDropRow = row;

		[self checkFiles:[pboard propertyListForType:NSFilenamesPboardType]];
	}

	return YES;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView
{
    return [tableData count];
}

- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if ([tableData count] > 0)
	{
		NSDictionary *rowData = [tableData objectAtIndex:row];
		
		return [rowData objectForKey:[tableColumn identifier]];
	}
	else
	{
		return nil;
	}
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSMutableDictionary *rowData = [tableData objectAtIndex:row];
    [rowData setObject:anObject forKey:[tableColumn identifier]];
}

- (BOOL)tableView:(NSTableView *)view writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	if (canBeReorderd)
	{
		id object = [tableData objectAtIndex:[[rows lastObject] integerValue]];
		NSData *data = [NSArchiver archivedDataWithRootObject:object];

		[pboard declareTypes:[NSArray arrayWithObjects:@"NSGeneralPboardType", @"KWRemoveRowPboardType", @"KWDraggedRows", nil] owner:nil];
		[pboard setData:data forType:@"NSGeneralPboardType"];
		[pboard setString:[[rows lastObject] stringValue] forType:@"KWRemoveRowPboardType"];
		[pboard setPropertyList:rows forType:@"KWDraggedRows"];
   
		return YES;
	}

	return NO;
}

///////////////////
// Other actions //
///////////////////

#pragma mark -
#pragma mark •• Other actions

//Check for rows
- (NSInteger)numberOfRows
{
	return [tableData count];
}

//Set total size
- (void)setTotal
{
	[totalText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Total size: %@", nil), [KWCommonMethods makeSizeFromFloat:[[self totalSize] cgfloatValue] * 2048]]];
}

//Calculate and return total size as CGFloat
- (NSNumber *)totalSize
{
	NSInteger numberOfRows = [tableData count];
	id firstObject;
	
	if (numberOfRows > 0)
		firstObject  = [tableData objectAtIndex:0];
	
	if (numberOfRows > 0 && [[[firstObject objectForKey:@"Name"] lowercaseString] isEqualTo:[dvdFolderName lowercaseString]] && isDVD)
	{
		return [NSNumber numberWithCGFloat:[KWCommonMethods calculateRealFolderSize:[firstObject objectForKey:@"Path"]]];
	}
	else
	{
		DRFolder *discRoot = [DRFolder virtualFolderWithName:@"Untitled"];
	
		NSInteger i;
		DRFSObject *fsObj;
		for (i = 0; i < numberOfRows; i ++)
		{
			fsObj = [DRFile fileWithPath:[[tableData objectAtIndex:i] valueForKey: @"Path"]];
			[discRoot addChild:fsObj];
		}
				
		if ([KWCommonMethods OSVersion] < 0x1040 | !isDVD)
		{
			//Just a filesystem since UDF isn't supported in Panther (not it will ever come here :-)
			[discRoot setExplicitFilesystemMask:(DRFilesystemInclusionMaskJoliet)];
		}
		else
		{
			[discRoot setExplicitFilesystemMask:(1<<2)];
		}

		return [NSNumber numberWithCGFloat:[[DRTrack trackForRootFolder:discRoot] estimateLength]];
	}
}

//Find name in array of folders
- (DRFolder *)checkArray:(NSArray *)array forFolderWithName:(NSString *)name
{
	NSInteger i;
	for (i = 0; i < [array count]; i ++)
	{
		DRFolder *currentFolder = [array objectAtIndex:i];
	
		if ([[currentFolder baseName] isEqualTo:name])
			return currentFolder;
	}
	
	return nil;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if (aSelector == @selector(burn:) | aSelector == @selector(saveImage:) | aSelector == @selector(saveDocument:) && [tableData count] == 0)
		return NO;
		
	return [super respondsToSelector:aSelector];
}

//Delete the temporary files used
- (void)deleteTemporayFiles:(NSNumber *)needed
{
	if ([needed boolValue])
	{
		NSInteger i;
		for (i = 0; i < [temporaryFiles count]; i ++)
		{
			[KWCommonMethods removeItemAtPath:[temporaryFiles objectAtIndex:i]];
		}
	}
	
	[temporaryFiles removeAllObjects];
}

//Use some c to get the real path
- (NSString *)getRealPath:(NSString *)inPath
{
	CFStringRef resolvedPath = nil;
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)inPath, kCFURLPOSIXPathStyle, NO);
	
	if (url != NULL) 
	{
		FSRef fsRef;
		
		if (CFURLGetFSRef(url, &fsRef)) 
		{
			Boolean targetIsFolder, wasAliased;
			
			if (FSResolveAliasFile (&fsRef, true, &targetIsFolder, &wasAliased) == noErr && wasAliased) 
			{
				CFURLRef resolvedurl = CFURLCreateFromFSRef(NULL, &fsRef);
				
				if (resolvedurl != NULL) 
				{
					resolvedPath = CFURLCopyFileSystemPath(resolvedurl, kCFURLPOSIXPathStyle);
					CFRelease(resolvedurl);
					resolvedurl = NULL;
				}
			}
		}
	
		CFRelease(url);
		url = NULL;
	}
	
	if ((NSString *)resolvedPath)
		return (NSString *)resolvedPath;
	else
		return inPath;
}

//Return tableData to external objects
- (NSMutableArray *)myDataSource
{
	return tableData;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	NSInteger maxCharacters = 32;
	NSString *nameString = [discName stringValue];
	
	if ([nameString length] > maxCharacters)
	{
		NSBeep();
	
		[discName setStringValue:[nameString substringWithRange:NSMakeRange(0, maxCharacters)]];
	}
}

@end
