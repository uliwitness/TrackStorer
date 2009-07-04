//
//  UKITunesPlaylist.h
//  TrackStorer
//
//  Created by Uli Kusterer on 25.03.06.
//  Copyright 2006 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class UKITunesLibrary;

@interface UKITunesPlaylist : NSObject
{
	UKITunesLibrary*	owner;
	NSDictionary*		playlistData;
	NSImage*			icon;
}

-(id)	initWithPlaylistDictionary: (NSDictionary*)plData owner: (UKITunesLibrary*)boss;

-(NSString*)		name;
-(NSImage*)			icon;
-(BOOL)				isMainLibrary;
-(BOOL)				isPodcasts;
-(BOOL)				isVideos;
-(BOOL)				isFolder;
-(BOOL)				isSmart;

-(int)				count;
-(NSDictionary*)	trackDictionaryForItemAtIndex: (int)n;

-(NSString*)		persistentID;
-(NSString*)		parentPersistentID;

@end
