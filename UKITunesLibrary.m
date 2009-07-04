//
//  UKITunesLibrary.m
//  TrackStorer
//
//  Created by Uli Kusterer on 25.03.06.
//  Copyright 2006 Uli Kusterer. All rights reserved.
//

#import "UKITunesLibrary.h"
#import "UKITunesPlaylist.h"


@implementation UKITunesLibrary

+(id)					defaultLibrary
{
	static UKITunesLibrary*	sharedInstance = nil;
	if( !sharedInstance )
		sharedInstance = [[[self class] alloc] init];
	
	return sharedInstance;
}

-(id)	init
{
	self = [super init];
	if( self )
	{
		NSPropertyListFormat	format = NSPropertyListXMLFormat_v1_0;
		NSString*				errorString = nil;
		NSData*					fileData = [NSData dataWithContentsOfFile: [self libraryPath]];
		libraryFileDictionary = [[NSPropertyListSerialization propertyListFromData: fileData
										mutabilityOption: NSPropertyListMutableContainers
										format: &format errorDescription: &errorString] retain];
		if( errorString )
			[errorString release];
	}
	
	return( self );
}


-(void)	dealloc
{
	[libraryFileDictionary release];
	libraryFileDictionary = nil;
	
	[playlistsByID release];
	playlistsByID = nil;
	
	[playlistIDs release];
	playlistIDs = nil;
	
	[playlistHierarchy release];
	playlistHierarchy = nil;
	
	// libraryPlaylist is stored nonretained, so no need to release here.
	libraryPlaylist = nil;
	
	[super dealloc];
}


-(NSString*)	libraryPath
{
	return [@"~/Music/iTunes/iTunes Music Library.xml" stringByExpandingTildeInPath];
}


-(UKITunesPlaylist*)	playlistAtIndex: (int)n
{
	NSDictionary*		dict = [[libraryFileDictionary objectForKey: @"Playlists"] objectAtIndex: n];
	UKITunesPlaylist*	pl = [[[UKITunesPlaylist alloc] initWithPlaylistDictionary: dict owner: self] autorelease];
	
	if( !libraryPlaylist && [pl isMainLibrary] )
		libraryPlaylist = dict;	// Also initialises the "library" playlist while it's at it. No need to retain, as the libraryFileDictionary already does that for us.
	
	return pl;
}


-(UKITunesPlaylist*)	playlistWithID: (NSString*)nme
{
	[self setUpLookupTables];
	
	// Look up playlist by persistent ID based on look-up-table:
	NSDictionary*	foundPL = [playlistsByID objectForKey: nme];
	if( !foundPL )
	{
		NSLLog(@"foundPL = %@", foundPL);
		return nil;
	}
	
	return [[[UKITunesPlaylist alloc] initWithPlaylistDictionary: foundPL owner: self] autorelease];
}

-(NSArray*)				playlistIDs
{
	if( !playlistIDs )
		[self setUpLookupTables];
	
	return playlistIDs;
}


-(int)					playlistCount
{
	NSArray*			playLists = [libraryFileDictionary objectForKey: @"Playlists"];
	return [playLists count];
}


-(NSArray*)				playlistHierarchy
{
	if( playlistHierarchy )
		return playlistHierarchy;
	
	NSArray*				playLists = [libraryFileDictionary objectForKey: @"Playlists"];
	NSEnumerator*			enny = [playLists objectEnumerator];
	int						plCount = [playLists count];
	NSMutableDictionary*	playlistsByPersistentIDs = [NSMutableDictionary dictionaryWithCapacity: plCount];
	NSMutableArray*			rootLevel = [[NSMutableArray alloc] initWithCapacity: plCount];
	
	NSDictionary*	currPL = nil;
	while(( currPL = [enny nextObject] ))
	{
		NSString*		persistentID = [currPL objectForKey: @"Playlist Persistent ID"];
		NSDictionary*	currEntry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										/*currPL, @"playlistDictionary",*/
										persistentID, @"persistentID",
										[NSMutableArray arrayWithCapacity: plCount], @"subItems",
										nil];
		[playlistsByPersistentIDs setObject: currEntry forKey: persistentID];
		
		NSString*				parentPersistentID = [currPL objectForKey: @"Parent Persistent ID"];
		if( parentPersistentID )
		{
			NSMutableDictionary*	parent = [playlistsByPersistentIDs objectForKey: parentPersistentID];
			NSMutableArray*			parentSubItems = [parent objectForKey: @"subItems"];
			[parentSubItems addObject: currEntry];
		}
		else
			[rootLevel addObject: currEntry];
	}
	
	playlistHierarchy = rootLevel;
}


-(NSDictionary*)	trackDictionaryByID: (NSNumber*)trackID
{
	NSDictionary*	tracksDict = [libraryFileDictionary objectForKey: @"Tracks"];
	if( !tracksDict )
	{
		NSLog(@"tracksDict == NULL");
		NSLog(@"libraryFileDictionary = %@", libraryFileDictionary);
		return nil;
	}
	NSDictionary*	dict = [tracksDict objectForKey: [trackID stringValue]];
	if( !dict )
	{
		NSLog(@"!dict");
		return nil;
	}
	return dict;
}


-(BOOL)					synchronize
{
	[libraryFileDictionary release];
	libraryFileDictionary = nil;

	[playlistHierarchy release];
	playlistHierarchy = nil;
	
	NSPropertyListFormat	format = NSPropertyListXMLFormat_v1_0;
	NSString*				errorString = nil;
	NSData*					fileData = [NSData dataWithContentsOfFile: [self libraryPath]];
	libraryFileDictionary = [[NSPropertyListSerialization propertyListFromData: fileData
									mutabilityOption: NSPropertyListMutableContainers
									format: &format errorDescription: &errorString] retain];
	if( errorString )
		[errorString release];

	[self rebuildLookupTables];
}


-(void)		rebuildLookupTables
{
	libraryPlaylist = nil;	// Causes rebuild in setUpLookupTables.
	[self setUpLookupTables];
}


-(void)		setUpLookupTables
{
	// This *must* rebuild if libraryPlaylist is NIL and all others have already
	//	been loaded because that's the trick rebuildLookupTables uses.
	if( playlistsByID && playlistIDs && libraryPlaylist )
		return;	// Already did our work, no need to burn cycles.
	
	NSArray*			playLists = [libraryFileDictionary objectForKey: @"Playlists"];
	NSEnumerator*		enny = [playLists objectEnumerator];
	
	if( playlistsByID )
	{
		[playlistsByID release];
		playlistsByID = nil;
	}
	if( playlistIDs )
	{
		[playlistIDs release];
		playlistIDs = nil;
	}
	playlistsByID = [[NSMutableDictionary alloc] init];
	playlistIDs = [[NSMutableArray alloc] initWithCapacity: [playLists count]];
	
	NSDictionary*	currPL = nil;
	while(( currPL = [enny nextObject] ))
	{
		[playlistsByID setObject: currPL forKey: [currPL objectForKey: @"Playlist Persistent ID"]];	// Initialise by-id lookup table.
		[playlistIDs addObject: [currPL objectForKey: @"Playlist Persistent ID"]];				// Initialise ordered list of persistent ids.
		NSNumber*	isMasterLibraryObj = [currPL objectForKey: @"Master"];
		BOOL		isMasterLibrary = isMasterLibraryObj != nil && [isMasterLibraryObj boolValue];
		if( isMasterLibrary )
			libraryPlaylist = currPL;	// Also initialises the "library" playlist while it's at it. No need to retain, as the libraryFileDictionary already does that for us.
	}
}


-(UKITunesPlaylist*)	mainLibraryPlaylist
{
	if( !libraryPlaylist )
		[self setUpLookupTables];
	
	return [[[UKITunesPlaylist alloc] initWithPlaylistDictionary: libraryPlaylist owner: self] autorelease];
}


-(NSURL*)				musicFolderURL
{
	NSString*	urlStr = [libraryFileDictionary objectForKey: @"Music Folder"];
	return [NSURL URLWithString: urlStr];
}


@end
