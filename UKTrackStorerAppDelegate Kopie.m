//
//  UKTrackStorerAppDelegate.m
//  TrackStorer
//
//  Created by Uli Kusterer on 13.06.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import "UKTrackStorerAppDelegate.h"
#import "UKCustomWindowFrame.h"
#import "UKITunesLibrary.h"


@protocol UKFrameSetBottomCornerRounded     // Method available in NSGrayFrame.

-(void) setBottomCornerRounded: (BOOL)rnd;

@end


@implementation UKTrackStorerAppDelegate

// -----------------------------------------------------------------------------
//  * CONSTRUCTOR:
// -----------------------------------------------------------------------------

-(id)   init
{
    if( (self = [super init]) )
    {
        playlists = [[NSMutableDictionary alloc] init];
        tracksOnDevice = [[NSMutableDictionary alloc] init];
        tracksToCopy = [[NSMutableDictionary alloc] init];
        tracksToDelete = [[NSMutableDictionary alloc] init];
        players = [[NSMutableDictionary alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"Players" ofType: @"plist"]];
        errorList = [[NSMutableArray alloc] init];
        prevPlaylistState = [[[NSUserDefaults standardUserDefaults] objectForKey: @"UKTrackStorerLastSyncPlaylists"] mutableCopy];
        if( !prevPlaylistState )
            prevPlaylistState = [[NSMutableDictionary alloc] init];
        
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                    selector: @selector(volumeMounted:) name: NSWorkspaceDidMountNotification object: nil];
    }
    
    return self;
}


// -----------------------------------------------------------------------------
//  * DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self];
    [playlists release];
    [tracksOnDevice release];
    [tracksToCopy release];
    [tracksToDelete release];
    [players release];
    [errorList release];
    [prevPlaylistState release];
    
    [super dealloc];
}


// -----------------------------------------------------------------------------
//  * DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) awakeFromNib
{
    // Set up pathname display control:
    [drivePath setAction: @selector(playerDriveChanged:)];
    [drivePath setTarget: self];
    [drivePath setCanChooseFiles: NO];
    [drivePath setCanChooseDirectories: YES];
    
    // Restore previous player path:
    NSString*   pdPath = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKTrackStorerPlayerDrivePath"];
    if( pdPath )
        [drivePath setStringValue: pdPath];
    
    // Fill "players" menu:
    [playerPopUp removeAllItems];
    [playerPopUp addItemsWithTitles: [[players allKeys] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)]];
    
    // Restore previous player type:
    pdPath = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKTrackStorerPlayerType"];
    if( pdPath )
        [playerPopUp selectItemWithTitle: pdPath];
    [playerPopUp synchronizeTitleAndSelectedItem];
}


// -----------------------------------------------------------------------------
//  playerSettings:
//      Return the settings dictionary for the currently selected MP3 player
//      type.
// -----------------------------------------------------------------------------

-(NSDictionary*)    playerSettings
{
    NSString*       currPlayer = [playerPopUp titleOfSelectedItem];
    return [players objectForKey: currPlayer];
}


// -----------------------------------------------------------------------------
//  refreshSizeDisplay:
//      Refresh the status bar with size info (used, free space on device).
//      If no player is currently mounted, write an error message in the status
//      field instead.
// -----------------------------------------------------------------------------

-(void) refreshSizeDisplay
{
    NSString*       dPath = [drivePath stringValue];
    if( dPath == nil || ![[NSFileManager defaultManager] fileExistsAtPath: dPath] )
    {
        [status setStringValue: @"No MP3 Player found. Select it and its type in the Preferences."];
        return;
    }
    
    NSEnumerator*   enny = [tracksOnDevice objectEnumerator];
    NSDictionary*   track = nil;
    NSDictionary*   playerSettings = [self playerSettings];
    int             size = 0;
    
    // Delete tracks we don't want anymore:
    while( (track = [enny nextObject]) )
        size += [[track objectForKey: @"Size"] intValue];
    
    // Now that we have room, copy over new ones:
    enny = [tracksToCopy objectEnumerator];
    while( (track = [enny nextObject]) )
        size += [[track objectForKey: @"Size"] intValue];
    
    // Calculate best display unit:
    float       finalSize = size;
    NSString*   unit = @"bytes";
    if( finalSize >= 1024 )
    {
        finalSize /= 1024;
        unit = @"kb";
        if( finalSize >= 1024 )
        {
            finalSize /= 1024;
            unit = @"MB";
        }
    }
    
    // Calculate best display unit:
    float       maxSize = [[playerSettings objectForKey: @"Capacity"] intValue] -size;
    NSString*   maxunit = @"bytes";
    if( maxSize >= 1024 )
    {
        maxSize /= 1024;
        maxunit = @"kb";
        if( maxSize >= 1024 )
        {
            maxSize /= 1024;
            maxunit = @"MB";
        }
    }
    
    // Display size info in status field:
    [status setStringValue: [NSString stringWithFormat: @"%.2f %@ used, %.2f %@ free", finalSize, unit, maxSize, maxunit]];
}


-(void) volumeMounted: (NSNotification*)notif
{
    NSString*   devPath = [[notif userInfo] objectForKey: @"NSDevicePath"];
    
	[[NSWorkspace sharedWorkspace] typeOfVolumeAtPath: devPath];
	
    if( [devPath isEqualToString: [drivePath stringValue]] )
    {
        // TODO: Might want to ask user here in case they accidentally removed/re-inserted the drive and don't wanna lose their checkmarks.
        [self markExistingFiles: nil];
    }
}


// -----------------------------------------------------------------------------
//  playerDriveChanged:
//      Called by drivePath to indicate user picked a different volume. Set
//      as drivePath's action in awakeFromNib.
// -----------------------------------------------------------------------------

-(void) playerDriveChanged: (id)sender
{
    NSString*   dPath = [drivePath stringValue];    // Get current path from drivePath view.
    
    // Save path in Prefs:
    [[NSUserDefaults standardUserDefaults] setObject: dPath forKey: @"UKTrackStorerPlayerDrivePath"];
    
    // If the user selected a valid and existing path, make sure checkmarks in library are up to date:
    if( dPath && [[NSFileManager defaultManager] fileExistsAtPath: dPath] )
        [self markExistingFiles: nil];
}


// -----------------------------------------------------------------------------
//  playerSettingsChanged:
//      Called by playerPopUp to indicate user picked a different player. Set
//      as playerPopUp's action in the NIB.
// -----------------------------------------------------------------------------

-(void) playerSettingsChanged: (id)sender
{
    // Get name of selected player:
    NSString*       currPlayer = [playerPopUp titleOfSelectedItem];
    NSString*       defPath = nil;
    
    // If no path has been set yet, get default path for this model from settings dictionary:
    if( [drivePath stringValue] == nil )
    {
        [drivePath setStringValue: defPath];
        defPath = [[players objectForKey: currPlayer] objectForKey: @"DefaultPath"];
    }

    // Save player name to Prefs:
    [[NSUserDefaults standardUserDefaults] setObject: currPlayer forKey: @"UKTrackStorerPlayerType"];
    
    // If we have a valid path now, make sure checkmarks in library are synced with player's state:
    if( defPath && [[NSFileManager defaultManager] fileExistsAtPath: defPath] )
        [self markExistingFiles: nil];
    else
        [self refreshSizeDisplay];  // Otherwise, at least update status bar to indicate there is no valid player.
}


// -----------------------------------------------------------------------------
//  applicationDidFinishLaunching:
//      Application about to start listening for events. Import iTunes library.
// -----------------------------------------------------------------------------

-(void) applicationDidFinishLaunching: (NSNotification*)notification
{
    NS_DURING
		NSLog( @"names=%@", [[UKITunesLibrary defaultLibrary] playlistNames] );
		/*int		x = 0, count = [[UKITunesLibrary defaultLibrary] playlistCount];
		
		for( x = 0; x < count; x++ )
		{
			UKITunesPlaylist*	currPL = [[UKITunesLibrary defaultLibrary] playlistAtIndex: x];
		}*/
		
        // Load library into NSDictionary:
        NSString*               libraryPath = [@"~/Music/iTunes/iTunes Music Library.xml" stringByExpandingTildeInPath];
        NSDictionary*           dict = [NSDictionary dictionaryWithContentsOfFile: libraryPath];
		NSLog(@"%@",dict);
        NSArray*                lists = [dict objectForKey: @"Playlists"];
        NSDictionary*           infos = [dict objectForKey: @"Tracks"];
        NSEnumerator*           plEnny = [lists objectEnumerator];
        NSDictionary*           plist = nil;
        sortedPlaylistNames = [[NSMutableArray alloc] init];
        NSMutableArray*         simplePlaylistNames = [NSMutableArray array];
        
        // Loop over library and extract playlists:
        while( (plist = [plEnny nextObject]) )
        {
            NSString*               nm = [plist objectForKey: @"Name"];
            NSMutableArray*         tracks = [NSMutableArray array];
            NSEnumerator*           trEnny = [[plist objectForKey: @"Playlist Items"] objectEnumerator];
            NSDictionary*           trItem = nil;
            BOOL                    isSmart = [plist objectForKey: @"Smart Info"] != nil;
            NSImage*                icon = nil;
            
            // Pick an icon and sort library to top with the other smart playlists:
            if( [nm isEqualToString: @"Library"] )
            {
                isSmart = YES;
                icon = [NSImage imageNamed: @"itunes_library"];
            }
            else if( [nm isEqualToString: @"Podcasts"] )
            {
                isSmart = YES;
                icon = [NSImage imageNamed: @"itunes_podcasts"];
            }
            else if( isSmart )
                icon = [NSImage imageNamed: @"itunes_smart_playlist"];
            else
                icon = [NSImage imageNamed: @"itunes_simple_playlist"];
            
            // Loop over tracks in playlists and add a *reference* to each one to the current playlist:
            while( (trItem = [trEnny nextObject]) )
            {
                NSString*       trID = [[trItem objectForKey: @"Track ID"] stringValue];
                NSDictionary*   obj = [infos objectForKey: trID];
                if( obj )
                    [tracks addObject: obj];
            }
            
            NSMutableDictionary*    plDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                tracks, @"Tracks",
                                                [NSNumber numberWithBool: isSmart], @"Smart",
                                                icon, @"Icon",
                                                nil];
            
            [playlists setObject: plDict forKey: nm];
            
            // Keep separate, ordered lists of simple and smart playlists so we can sort them like iTunes does:
            if( isSmart )
                [sortedPlaylistNames addObject: nm];
            else
                [simplePlaylistNames addObject: nm];
        }
    
        // Fix smart playlist order:
        // Podcasts at top...
        [sortedPlaylistNames removeObject: @"Podcasts"];
        [sortedPlaylistNames insertObject: @"Podcasts" atIndex: 0];
        // Library even on top of Podcasts:
        [sortedPlaylistNames removeObject: @"Library"];
        [sortedPlaylistNames insertObject: @"Library" atIndex: 0];
        // Append simple lists to our list of smart playlists:
        [sortedPlaylistNames addObjectsFromArray: simplePlaylistNames];
        [playlistsView reloadData];
        
        // If we have an MP3 player volume, make sure those on the player get the proper checkmarks:
        if( [drivePath stringValue] != nil )
            [self markExistingFiles: nil];
        else
            [self refreshSizeDisplay];
    NS_HANDLER
        NSLog(@"Error: %@", localException);
    NS_ENDHANDLER
        
    // Make sheet's bottom corners square:
    NSView* frmView = [[errorListView window] contentView];
    NSView* prevView = frmView;
    
    while( (frmView = [frmView superview]) != nil )
        prevView = frmView;
    
    [(id<UKFrameSetBottomCornerRounded>)prevView setBottomCornerRounded: NO];
}


// -----------------------------------------------------------------------------
//  applicationWillTerminate:
//      Save state of playlists to prefs so we can sync them up.
// -----------------------------------------------------------------------------

-(void) applicationWillTerminate: (NSNotification*)notification
{
    [[NSUserDefaults standardUserDefaults] setObject: prevPlaylistState forKey: @"UKTrackStorerLastSyncPlaylists"];
}


// -----------------------------------------------------------------------------
//  markExistingFiles:
//      Loop over all tracks in the main library and podcasts list and determine
//      whether files for them exist on the MP3 player.
// -----------------------------------------------------------------------------

-(void) markExistingFiles: (id)sender
{
    // Only do this time-consuming check if there is a player to check against:
    if( [[NSFileManager defaultManager] fileExistsAtPath: [drivePath stringValue]] )
    {
        [self markExistingFilesInLibrary: @"Library"];
        [self markExistingFilesInLibrary: @"Podcasts"];
        
        [self markChangedFilesInLibraries];
    }
    
    [self refreshSizeDisplay];
}


-(void) markChangedFilesInLibraries
{
    NSEnumerator*           keyEnny = [playlists keyEnumerator];
    NSEnumerator*           valEnny = [playlists objectEnumerator];
    NSString*               currPlistName = nil;
    NSMutableDictionary*    currPlist = nil;
    int                     x = 0;
    
    if( !prevPlaylistState )
        return;
    
    // Set up & show progress bar:
    [status setStringValue: [NSString stringWithFormat: @"Looking for playlist changes..."]];
    [progress setMaxValue: [playlists count]];
    [progress setDoubleValue: 0];
    [progress setHidden: NO];
    [progress display];
    
    while( (currPlistName = [keyEnny nextObject]) )
    {
        currPlist = [valEnny nextObject];
        
        [status setStringValue: [NSString stringWithFormat: @"Looking for changes in \"%@\"", currPlistName]];
        [status display];
        
        NSMutableDictionary*    currTrack = nil;
        NSMutableDictionary*    currPlistLastTimeDictionary = [[[prevPlaylistState objectForKey: currPlistName] mutableCopy] autorelease];
        NSArray*                currPlistLastTimeSyncedTrackIDs = [currPlistLastTimeDictionary objectForKey: @"Track IDs"];
        if( !currPlistLastTimeSyncedTrackIDs )
            currPlistLastTimeSyncedTrackIDs = [NSArray array];
        NSString*               currTrackID = nil;
        NSString*               dstPath = nil;
        NSMutableArray*         currPlistCurrentTrackIDs = [NSMutableArray array];
        NSNumber*               copyThisPlist = [currPlistLastTimeDictionary objectForKey: @"copy"];
        
        if( copyThisPlist && [copyThisPlist boolValue] )
        {
            NSEnumerator*           trackEnny = [[currPlist objectForKey: @"Tracks"] objectEnumerator];
            
            [currPlist setObject: copyThisPlist forKey: @"copy"];   // Make sure it's flagged as needing to be synced each time.
            
            // First find tracks to copy over:
            while( (currTrack = [trackEnny nextObject]) )
            {
                currTrackID = [currTrack objectForKey: @"Track ID"];
                [currPlistCurrentTrackIDs addObject: currTrackID];
                if( ![currPlistLastTimeSyncedTrackIDs containsObject: currTrackID] )    // File wasn't in this playlist in last sync.
                    [self addTrackToPlayer: currTrack];
            }
            
            // Now find tracks to delete:
            trackEnny = [currPlistLastTimeSyncedTrackIDs objectEnumerator];
            
            while( (currTrackID = [trackEnny nextObject]) )
            {
                if( ![currPlistCurrentTrackIDs containsObject: currTrackID] )   // File went away since last sync.
                    [self removeTrackFromPlayer: currTrack];
            }
            
            // Remember this new state of the playlist:
            [currPlistLastTimeDictionary setObject: currPlistCurrentTrackIDs forKey: @"Track IDs"];
        }
        
        [progress setDoubleValue: ++x];
        [progress display];
    }

    // Hide progress bar again:
    [progress setHidden: YES];
    
    [self refreshSizeDisplay];
}


// -----------------------------------------------------------------------------
//  markExistingFilesInLibrary:
//      Loop over all tracks in the library of specified name and determine
//      whether files for them exist on the MP3 player.
// -----------------------------------------------------------------------------

-(void) markExistingFilesInLibrary: (NSString*)libName
{
    NSDictionary*   plist = [playlists objectForKey: libName];
    NSArray*        tracks = [plist objectForKey: @"Tracks"];
    NSEnumerator*   enny = [tracks objectEnumerator];
    NSDictionary*   track = nil;
    int             x = 0;
    
    if( !tracks )   // No such playlist?
        return;     // Do nothing.
    
    // Set up & show progress bar:
    [status setStringValue: [NSString stringWithFormat: @"Checking files in \"%@\"", libName]];
    [progress setMaxValue: [tracks count]];
    [progress setDoubleValue: 0];
    [progress setHidden: NO];
    [progress display];
    
    // Loop and mark each track:
    while( (track = [enny nextObject]) )
    {
        [self markOneTrackIfItExists: track];
    
        [progress setDoubleValue: ++x];
        [progress display];
    }

    // Hide progress bar again:
    [progress setHidden: YES];
    
    [self refreshSizeDisplay];
}


// -----------------------------------------------------------------------------
//  markTracksThatExist:
//      Loop over all tracks in the specified array of tracks and determine
//      whether files for them exist on the MP3 player. (currently unused)
// -----------------------------------------------------------------------------

-(void) markTracksThatExist: (NSArray*)tracks
{
    NSEnumerator*   enny = [tracks objectEnumerator];
    NSDictionary*   track = nil;
    
    while( (track = [enny nextObject]) )
    {
        [self markOneTrackIfItExists: track];
    
        [progress animate: nil];
        [progress display];
    }
}


// -----------------------------------------------------------------------------
//  filterOutSlashes:
//      Take a filename and filter out all slashes and other dangerous chars
//      that the MP3 player doesn't like in its filenames.
// -----------------------------------------------------------------------------

-(NSString*)    filterOutSlashes: (NSString*)str
{
    NSMutableString* mstr = [[str mutableCopy] autorelease];
    
    [mstr replaceOccurrencesOfString: @"/" withString: @"-" options:0 range: NSMakeRange(0,[str length])];
    [mstr replaceOccurrencesOfString: @":" withString: @"-" options:0 range: NSMakeRange(0,[str length])];
    [mstr replaceOccurrencesOfString: @"\"" withString: @"_" options:0 range: NSMakeRange(0,[str length])];
    
    return mstr;
}


// -----------------------------------------------------------------------------
//  pathForTrack:
//      Build a pathname for the file corresponding to a specific track on the
//      MP3 player.
// -----------------------------------------------------------------------------

-(NSString*)     pathForTrack: (NSDictionary*)track
{
    NSString*           dstPath = [drivePath stringValue];
    NSString*           artist = [self filterOutSlashes: [track objectForKey: @"Artist"]];
    if( !artist )
        artist = @"Unknown";
    dstPath = [dstPath stringByAppendingFormat: @"/%@ - %@.%@", artist,
                                                                [self filterOutSlashes: [track objectForKey: @"Name"]],
                                                                [self filterOutSlashes: [[track objectForKey: @"Location"] pathExtension]] ];
    return dstPath;
}


// -----------------------------------------------------------------------------
//  markOneTrackIfItExists:
//      Check whether the file for the specified track exists. If it does, mark
//      that track and add it to the "tracks on device" array so we know it
//      already is on the player.
// -----------------------------------------------------------------------------

-(void) markOneTrackIfItExists: (NSDictionary*)track
{
    NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
    NSString*           dstPath = [self pathForTrack: track];
    
    BOOL    exists = [[NSFileManager defaultManager] fileExistsAtPath: dstPath];
    [(NSMutableDictionary*)track setObject: [NSNumber numberWithBool: exists] forKey: @"copy"];
    
    if( exists )
        [tracksOnDevice setObject: track forKey: dstPath];
    
    [status setStringValue: [NSString stringWithFormat: @"Checking Player for \"%@\".", [dstPath lastPathComponent]]];
    [status display];
    
    [progress animate: nil];
    [progress display];
    [pool release];
}


// -----------------------------------------------------------------------------
//  copyOverFiles:
//      Loop over our list of files to copy and delete and actually copy/delete
//      them. Also clears the copy/delete lists after that.
// -----------------------------------------------------------------------------

-(void) copyOverFiles: (id)sender
{
    NSEnumerator*   enny = [tracksToDelete objectEnumerator];
    NSDictionary*   track = nil;
    int             x = 0;
    int             delCount = [tracksToDelete count];
    
    [errorList removeAllObjects];
    
    [progress setMaxValue: delCount +[tracksToCopy count]];
    [progress setDoubleValue: 0];
    [progress setHidden: NO];
    [progress display];
    
    // Delete tracks we don't want anymore:
    while( (track = [enny nextObject]) )
    {
        [self deleteOneTrack: track];
        [progress setDoubleValue: ++x];
        [progress display];
    }
    [tracksToDelete removeAllObjects];
    [scheduledForDeleteView reloadData];
   
    // Now that we have room, copy over new ones:
    enny = [tracksToCopy objectEnumerator];
    while( (track = [enny nextObject]) )
    {
        [self copyOneTrack: track];
        [progress setDoubleValue: ++x];
        [progress display];
    }
    
    // Remove deleted items from on-device list and add new ones:
    [status setStringValue: @"Cleaning up..."];

    enny = [tracksToCopy keyEnumerator];
    NSEnumerator*   venny = [tracksToCopy objectEnumerator];
    NSString*       currval = nil;
    NSDictionary*   currkey = nil;
    while( (currkey = [enny nextObject]) )
    {
        currval = [venny nextObject];
        [tracksOnDevice setObject: currval forKey: currkey];
    }
    [tracksToCopy removeAllObjects];
    [scheduledForCopyView reloadData];
    [onDeviceView reloadData];
    
    [self refreshSizeDisplay];
    [progress setHidden: YES];
    
    // Had errors? Show them to user:
    if( [errorList count] > 0 )
    {
        NSBeep();
        [NSApp beginSheet: [errorListView window] modalForWindow: [playlistsView window]
                modalDelegate: self didEndSelector: @selector(errorSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    }
    else
        [self closeErrorSheet: nil];
    [errorListView reloadData];
}


// -----------------------------------------------------------------------------
//  closeErrorSheet:
//      OK-button-action for the error list sheet.
// -----------------------------------------------------------------------------

-(void) closeErrorSheet: (id)sender
{
    [NSApp endSheet: [errorListView window]];
}


// -----------------------------------------------------------------------------
//  errorSheetDidEnd:returnCode:contextInfo:
//      Error list sheet's modal session ended. Close it.
// -----------------------------------------------------------------------------

-(void) errorSheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet orderOut: nil];
}


// -----------------------------------------------------------------------------
//  copyOneTrack:
//      Copies the file referenced by the specified track dictionary onto the
//      MP3 player. Only copies the data forks of the files.
// -----------------------------------------------------------------------------

-(BOOL) copyOneTrack: (NSDictionary*)track
{
    NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
    NSString*           srcPath = [[NSURL URLWithString: [track objectForKey: @"Location"]] path];
    NSString*           dstPath = [self pathForTrack: track];
    NSArray*            allowedExts = [[self playerSettings] objectForKey: @"SupportedExtensions"];
    NSString*           pathExt = [[dstPath pathExtension] lowercaseString];
    BOOL                success = NO;
    NSString*           errMsg = nil;
    
    // Check whether we can copy at all, and then actually copy.
    if( ![[NSFileManager defaultManager] fileExistsAtPath: srcPath] )   // Source file is there?
    {
        errMsg = [NSString stringWithFormat: @"Source \"%@\" is missing.", [srcPath lastPathComponent]];
        [status setStringValue: errMsg];
        [status display];
        
        [errorList addObject: [NSDictionary dictionaryWithObjectsAndKeys: @"Source file is missing.", @"Reason", dstPath, @"File", nil]];
    }
    else if( [[NSFileManager defaultManager] fileExistsAtPath: dstPath] )   // Dest file isn't there?
    {
        errMsg = [NSString stringWithFormat: @"File \"%@\" already exists.", [dstPath lastPathComponent]];
        [status setStringValue: errMsg];
        [status display];
        
        [errorList addObject: [NSDictionary dictionaryWithObjectsAndKeys: @"File already exists.", @"Reason", dstPath, @"File", nil]];
    }
    else if( ![allowedExts containsObject: pathExt] )   // File type is supported by player?
    {
        errMsg = [NSString stringWithFormat: @"Player can't play files of type \"%@\".", pathExt];
        [status setStringValue: errMsg];
        [status display];
        
        [errorList addObject: [NSDictionary dictionaryWithObjectsAndKeys: errMsg, @"Reason", dstPath, @"File", nil]];
    }
    else    // All OK! Read file into RAM, write to MP3 player's drive:
    {
        [status setStringValue: [NSString stringWithFormat: @"Copying \"%@\"", [dstPath lastPathComponent]]];
        [status display];
        NSData*     fileData = [NSData dataWithContentsOfFile: srcPath];    // Read file.
        if( ![fileData writeToFile: dstPath atomically: NO] )               // Write out new file.
        {
            errMsg = [NSString stringWithFormat: @"Couldn't copy from \"%@\".", srcPath];
            [status setStringValue: errMsg];
            [status display];
            
            [errorList addObject: [NSDictionary dictionaryWithObjectsAndKeys: errMsg, @"Reason", dstPath, @"File", nil]];
        }
        else
            success = YES;
    }
    
    [progress animate: nil];
    [progress display];
    [pool release];
    
    return success;
}


// -----------------------------------------------------------------------------
//  deleteOneTrack:
//      Deletes the file referenced by the specified track dictionary from the
//      MP3 player.
// -----------------------------------------------------------------------------

-(void) deleteOneTrack: (NSDictionary*)track
{
    NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
    NSString*           dstPath = [self pathForTrack: track];
    
    if( ![[NSFileManager defaultManager] fileExistsAtPath: dstPath] )
    {
        [status setStringValue: [NSString stringWithFormat: @"Couldn't find \"%@\".", [dstPath lastPathComponent]]];
        [status display];
            
        [errorList addObject: [NSDictionary dictionaryWithObjectsAndKeys: @"No file to Delete.", @"Reason", dstPath, @"File", nil]];
    }
    else
    {
        if( ![[NSFileManager defaultManager] removeFileAtPath: dstPath handler: nil] )
        {
            [status setStringValue: [NSString stringWithFormat: @"Couldn't delete \"%@\".", [dstPath lastPathComponent]]];
            [errorList addObject: [NSDictionary dictionaryWithObjectsAndKeys: @"Delete failed. Do you have Permissions?", @"Reason", dstPath, @"File", nil]];
        }
        else
            [status setStringValue: [NSString stringWithFormat: @"Deleted \"%@\".", [dstPath lastPathComponent]]];
        [status display];
    }
    
    [progress animate: nil];
    [progress display];
    [pool release];
}


// -----------------------------------------------------------------------------
//  Table view data source methods:
// -----------------------------------------------------------------------------

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    if( tableView == playlistsView )
        return [[playlists allKeys] count];
    else if( tableView == tracksView )
    {
        int             selRow = [playlistsView selectedRow];
        if( selRow > -1 )
        {
            NSDictionary*   plist = [playlists objectForKey: [sortedPlaylistNames objectAtIndex: selRow]];
            NSArray*        tracks = [plist objectForKey: @"Tracks"];
            
            return [tracks count];
        }
        else
            return 0;
    }
    else if( tableView == scheduledForCopyView )
        return [[tracksToCopy allKeys] count];
    else if( tableView == scheduledForDeleteView )
        return [[tracksToDelete allKeys] count];
    else if( tableView == onDeviceView )
        return [[tracksOnDevice allKeys] count];
    else if( tableView == errorListView )
        return [errorList count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    NSString*   ident = [tableColumn identifier];
    if( tableView == playlistsView )
    {
        NSString*   currKey = [sortedPlaylistNames objectAtIndex: row];
        if( [ident isEqualToString: @"Name"] )
            return currKey;
        else
            return [[playlists objectForKey: currKey] objectForKey: ident];
    }
    else if( tableView == tracksView )
    {
        int             selRow = [playlistsView selectedRow];
        if( selRow > -1 )
        {
            NSDictionary*   plist = [playlists objectForKey: [sortedPlaylistNames objectAtIndex: selRow]];
            NSArray*        tracks = [plist objectForKey: @"Tracks"];
            
            if( [ident isEqualToString: @"Location"] )
            {
                NSString*       path = [[NSURL URLWithString: [[tracks objectAtIndex: row] objectForKey: ident]] path];
                NSArray*        comps = [[NSFileManager defaultManager] componentsToDisplayForPath: path];
                NSString*       vol = [comps objectAtIndex: 0];
                NSString*       nm = [comps objectAtIndex: [comps count] -1];
                NSString*       dir = nil;
                if( [comps count] > 2 )
                    dir = [comps objectAtIndex: [comps count] -2];
                
                if( dir )
                    return [NSString stringWithFormat: @"%@ in %@ on %@", nm, dir, vol];
                else
                    return [NSString stringWithFormat: @"%@ on %@", nm, vol];
            }
            else
                return [[tracks objectAtIndex: row] objectForKey: ident];
        }
        else
            return @"";
    }
    else if( tableView == scheduledForCopyView )
        return [[[tracksToCopy allKeys] objectAtIndex: row] lastPathComponent];
    else if( tableView == scheduledForDeleteView )
        return [[[tracksToDelete allKeys] objectAtIndex: row] lastPathComponent];
    else if( tableView == onDeviceView )
        return [[[tracksOnDevice allKeys] objectAtIndex: row] lastPathComponent];
    else if( tableView == errorListView )
    {
        if( [ident isEqualToString: @"File"] )
            return [[[errorList objectAtIndex: row] objectForKey: ident] lastPathComponent];
        else
            return [[errorList objectAtIndex: row] objectForKey: ident];
    }
}


// Disable "copy" checkbox for tracks that our player can't handle:
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if( tableView == tracksView )
    {
        int             selRow = [playlistsView selectedRow];
        if( selRow > -1 )
        {
            NSDictionary*   plist = [playlists objectForKey: [sortedPlaylistNames objectAtIndex: selRow]];
            NSArray*        tracks = [plist objectForKey: @"Tracks"];
            NSString*       ident = [tableColumn identifier];
            NSString*       path = [[NSURL URLWithString: [[tracks objectAtIndex: row] objectForKey: @"Location"]] path];
            NSArray*        allowedExts = [[self playerSettings] objectForKey: @"SupportedExtensions"];
            BOOL            isEnabled = [allowedExts containsObject: [[path pathExtension] lowercaseString]];
            
            [cell setEnabled: isEnabled];
            if( ![ident isEqualToString: @"copy"] )
            {
                if( isEnabled )
                    [cell setTextColor: [NSColor blackColor]];
                else
                    [cell setTextColor: [NSColor lightGrayColor]];
            }
        }
    }
}


-(void)     addTrackToPlayer: (NSDictionary*)track
{
    NSString*       dstPath = [self pathForTrack: track];
    NSArray*        allowedExts = [[self playerSettings] objectForKey: @"SupportedExtensions"];
    
    if( [allowedExts containsObject: [[dstPath pathExtension] lowercaseString]] ) // Only allow adding tracks that player can handle. Necessary since user might check an entire playlist for sync, which would include m4as or other stuff only ipods can handle.
    {
        if( [tracksToDelete objectForKey: dstPath] )    // Is there, but scheduled for deletion?
        {
            // Move it back to "on device" list:
            [tracksToDelete removeObjectForKey: dstPath];
            [tracksOnDevice setObject: track forKey: dstPath];
        }
        else if( [tracksOnDevice objectForKey: dstPath] == nil )    // Is not there? Move it to "scheduled to copy" list.
            [tracksToCopy setObject: track forKey: dstPath];
    }
}

-(void)     removeTrackFromPlayer: (NSDictionary*)track
{
    NSString*       dstPath = [self pathForTrack: track];

    if( [tracksOnDevice objectForKey: dstPath] )    // Is there?
    {
        // Move it to "to delete" list:
        [tracksOnDevice removeObjectForKey: dstPath];
        [tracksToDelete setObject: track forKey: dstPath];
    }
    else if( [tracksToCopy objectForKey: dstPath] )    // Scheduled to be copied? Remove from list again.
        [tracksToCopy removeObjectForKey: dstPath];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    NSString*       ident = [tableColumn identifier];
    if( tableView == playlistsView )
    {
        NSString*               currKey = [sortedPlaylistNames objectAtIndex: row];
        NSMutableDictionary*    plist = [playlists objectForKey: currKey];
        [plist setObject: object forKey: ident];
        
        if( [ident isEqualToString: @"copy"] )
        {
            NSEnumerator*   enny = [[plist objectForKey: @"Tracks"] objectEnumerator];
            NSDictionary*   track = nil;
            
            while( (track = [enny nextObject]) )
            {
                BOOL            copyExplicitly = [[track objectForKey: @"copy"] boolValue];
                if( [object boolValue] /*&& !copyExplicitly*/ )     // Want it on device and isn't set to be copied by itself?
                    [self addTrackToPlayer: track];
                else /*if( !copyExplicitly )*/                      // Want it off device and isn't checked explicitly?
                    [self removeTrackFromPlayer: track];
            }
            
            // Make sure this checkbox's state gets saved to prefs:
            NSMutableDictionary*    prevPlist = [[[prevPlaylistState objectForKey: currKey] mutableCopy] autorelease];
            if( !prevPlist )
            {
                prevPlist = [NSMutableDictionary dictionary];
            }
			[prevPlaylistState setObject: prevPlist forKey: currKey];
            [prevPlist setObject: object forKey: @"copy"];
        }
    }
    else if( tableView == tracksView )
    {
        int             selRow = [playlistsView selectedRow];
        if( selRow > -1 )
        {
            NSDictionary*           plist = [playlists objectForKey: [sortedPlaylistNames objectAtIndex: selRow]];
            NSArray*                tracks = [plist objectForKey: @"Tracks"];
            NSMutableDictionary*    track = [tracks objectAtIndex: row];
            [track setObject: object forKey: ident];
            
            if( [ident isEqualToString: @"copy"] )
            {
                NSString*       dstPath = [self pathForTrack: track];
                
                if( [object boolValue] )    // Want it on device?
                    [self addTrackToPlayer: track];
                else    // Want it off device?
                    [self removeTrackFromPlayer: track];
                [self refreshSizeDisplay];
            }
        }
    }
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if( [notification object] == playlistsView )    // User selected different playlist?
        [tracksView reloadData];                    // Load its contents into the list of tracks.
    else if( [notification object] == tracksView )
    {
        //
    }
}


-(void) ejectMP3PlayerVolume: (id)sender
{
    NSString*       path = [drivePath stringValue];
    
    if( path )
        [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath: path];
    
    [self refreshSizeDisplay];
}

@end
