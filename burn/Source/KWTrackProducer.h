//
//  KWTrackProducer.h
//  Burn
//
//  Created by Maarten Foukhar on 26-11-08.
//  Copyright 2009 Kiwi Fruitware. All rights reserved.
//

#include <stdio.h>

#import <Cocoa/Cocoa.h>
#import <DiscRecording/DiscRecording.h>
#import "KWCommonMethods.h"

@interface KWTrackProducer : NSObject 
{
	FILE     *file;
	NSFileHandle *readHandle;
	NSFileHandle *writeHandle;
	NSFileHandle *calcHandle;
	NSPipe *calcPipe;
	NSString *folderPath;
	NSString *discName;
	NSArray *mpegFiles;
	//Types 1 = hfsstandard; 2 = udf; 3 = dvd-video; 4 = vcd; 5 = svcd; 6 = audiocd 7 = dvd-audio
	NSInteger	type;
	BOOL createdTrack;
	NSTask *trackCreator;
	NSPipe *trackPipe;
	NSInteger currentImageSize;
	NSTimer *prepareTimer;
	NSString *currentAudioTrack;
}

//Track actions
- (NSArray *)getTracksOfCueFile:(NSString *)path;
- (DRTrack *)getTrackForImage:(NSString *)path withSize:(NSInteger)size;
- (DRTrack *)getTrackForFolder:(NSString *)path ofType:(NSInteger)imageType withDiscName:(NSString *)name;
- (NSArray *)getTrackForVCDMPEGFiles:(NSArray *)files withDiscName:(NSString *)name ofType:(NSInteger)imageType;
- (NSArray *)getTracksOfLayout:(NSString *)layout withTotalSize:(NSInteger)size;
- (NSArray *)getTracksOfVcd;
- (NSArray *)getTracksOfAudioCD:(NSString *)path withToc:(NSDictionary *)toc;
- (DRTrack *)getAudioTrackForPath:(NSString *)path;
- (DRTrack *)getTrackWithTrackProperties:(NSDictionary *)trackProperties;

//Stream actions
- (void)createImage;
- (void)createVcdImage;
- (void)createAudioTrack:(NSString *)path;

//Other
- (CGFloat)imageSize;
- (DRTrack *)createDefaultTrackWithSize:(NSInteger)size;
- (CGFloat)audioTrackSizeAtPath:(NSString *)path;

@end
