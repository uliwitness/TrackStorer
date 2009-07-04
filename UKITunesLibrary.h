//
//  UKITunesLibrary.h
//  TrackStorer
//
//  Created by Uli Kusterer on 25.03.06.
//  Copyright 2006 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UKITunesPlaylist.h"

@interface UKITunesLibrary : NSObject
{
	NSDictionary*			libraryFileDictionary;	// The entire library plist loaded as a dictionary.
	NSMutableDictionary*	playlistsByID;			// Lazy-loaded dictionary of all playlists with their persistent IDs as keys.
	NSDictionary*			libraryPlaylist;		// Lazy-loaded library dictionary for the main "master library". NOT RETAINED, AS libraryFileDictionary already retains this.
	NSMutableArray*			playlistIDs;			// Lazy-loaded array of all playlist persistent IDs.
	NSMutableArray*			playlistHierarchy;		// Lazy-loaded hierarchy of our playlists.
}

+(id)					defaultLibrary;	// Singleton object of this class.

-(int)					playlistCount;
-(UKITunesPlaylist*)	playlistAtIndex: (int)n;

-(NSArray*)				playlistIDs;
-(UKITunesPlaylist*)	playlistWithID: (NSString*)nme;

-(NSArray*)				playlistHierarchy;				// Returns array of dictionaries with persistentID and subItems keys containing the ID of each playlist and an array with the dictionaries of its sub-playlists.

-(UKITunesPlaylist*)	mainLibraryPlaylist;			// Master library ("Library" on English systems). Doesn't necessarily return the same object each time.
-(NSURL*)				musicFolderURL;
-(NSString*)			libraryPath;					// Path to "iTunes Music Library.xml" file that this reads. You could e.g. hand this to a KQueue to watch for changes and have it call -synchronize to reload the library.

-(BOOL)					synchronize;					// Reload the library.

// Private:
-(void)				setUpLookupTables;
-(void)				rebuildLookupTables;
-(NSDictionary*)	trackDictionaryByID: (NSNumber*)trackID;

@end
