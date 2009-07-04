//
//  UKITunesPlaylist.m
//  TrackStorer
//
//  Created by Uli Kusterer on 25.03.06.
//  Copyright 2006 Uli Kusterer. All rights reserved.
//

#import "UKITunesPlaylist.h"
#import "UKITunesLibrary.h"


@implementation UKITunesPlaylist

-(id)	initWithPlaylistDictionary: (NSDictionary*)plData owner: (UKITunesLibrary*)boss
{
	self = [super init];
	if( !self )
		return nil;
	
	playlistData = [plData retain];
	owner = [boss retain];
	
	return self;
}

-(void)	dealloc
{
	[playlistData release];
	playlistData = nil;
	[owner release];
	owner = nil;
	[icon release];
	icon = nil;
	
	[super dealloc];
}


-(BOOL)	isMainLibrary
{
	NSNumber*	theFlagObj = [playlistData objectForKey: @"Master"];
	BOOL		theFlag = theFlagObj != nil && [theFlagObj boolValue];
	
	return theFlag;
}

-(BOOL)	isPodcasts
{
	NSNumber*	theFlagObj = [playlistData objectForKey: @"Podcasts"];
	BOOL		theFlag = theFlagObj != nil && [theFlagObj boolValue];
	
	return theFlag;
}

-(BOOL)	isVideos
{
	NSNumber*	theFlagObj = [playlistData objectForKey: @"Videos"];
	BOOL		theFlag = theFlagObj != nil && [theFlagObj boolValue];
	
	return theFlag;
}

-(BOOL)	isSmart
{
	return( [playlistData objectForKey: @"Smart Info"] != nil );
}

-(BOOL)	isFolder
{
	NSNumber*	theFlagObj = [playlistData objectForKey: @"Folder"];
	BOOL		theFlag = theFlagObj != nil && [theFlagObj boolValue];
	
	return theFlag;
}

-(NSString*)	name
{
	return [playlistData objectForKey: @"Name"];
}

-(NSImage*)	icon
{
	if( !icon )
	{
		if( [self isMainLibrary] )
			icon = [[NSImage imageNamed: @"itunes_library"] retain];
		else if( [self isPodcasts] )
			icon = [[NSImage imageNamed: @"itunes_podcasts"] retain];
		else if( [self isVideos] )
			icon = [[NSImage imageNamed: @"itunes_videos"] retain];
		else if( [self isFolder] )
			icon = [[NSImage imageNamed: @"itunes_folder"] retain];
		else if( [self isSmart] )
			icon = [[NSImage imageNamed: @"itunes_smart_playlist"] retain];
		else
			icon = [[NSImage imageNamed: @"itunes_simple_playlist"] retain];
	}
	
	return icon;
}

-(int)	count
{
	return [[playlistData objectForKey: @"Playlist Items"] count];
}

-(NSDictionary*)	trackDictionaryForItemAtIndex: (int)n
{
	NSArray*		playlistItems = [playlistData objectForKey: @"Playlist Items"];
	if( !playlistItems )
	{
		NSLog(@"playlistItems == NULL");
		return nil;
	}
	NSDictionary*	playlistItem = [playlistItems objectAtIndex: n];
	if( !playlistItem )
	{
		NSLog(@"playlistItems = %@", playlistItems);
		return nil;
	}
	
	NSNumber*		trackID = [playlistItem objectForKey: @"Track ID"];
	if( !trackID )
	{
		NSLog(@"playlistItem = %@", playlistItem);
		return nil;
	}
	
	return [owner trackDictionaryByID: trackID];
}

-(NSString*)		persistentID
{
	return [playlistData objectForKey: @"Playlist Persistent ID"];
}


-(NSString*)		parentPersistentID
{
	return [playlistData objectForKey: @"Parent Persistent ID"];
}


-(NSString*) description
{
	return [NSString stringWithFormat: @"%@ { playlistData = %@, owner = %lx }", NSStringFromClass( [self class] ), playlistData, (int)owner];
}


@end
