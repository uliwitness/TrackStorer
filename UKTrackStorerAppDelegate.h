//
//  UKTrackStorerAppDelegate.h
//  TrackStorer
//
//  Created by Uli Kusterer on 13.06.05.
//  Copyright 2005 M. Uli Kusterer. All rights reserved.
//

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "UKFilePathView.h"


// -----------------------------------------------------------------------------
//  Application delegate:
// -----------------------------------------------------------------------------

@interface UKTrackStorerAppDelegate : NSObject
{
    NSMutableDictionary*            playlists;              // Our "light" version of the iTunes library.
    NSMutableArray*                 sortedPlaylistNames;    // Alphabetically sorted allKeys dictionary of "playlists".
    IBOutlet NSOutlineView*         playlistsView;          // Shows sortedPlaylistNames.
    IBOutlet NSTableView*           tracksView;             // List of tracks from the currently selected playlist.
    NSMutableDictionary*            tracksOnDevice;         // Tracks that already are on the MP3 player. (File paths are keys)
    NSMutableDictionary*            tracksToCopy;           // Tracks that will be copied to the device. (File paths are keys)
    NSMutableDictionary*            tracksToDelete;         // Tracks that will be deleted from the device. (File paths are keys)
    IBOutlet NSTableView*           scheduledForCopyView;   // Shows tracksToCopy
    IBOutlet NSTableView*           scheduledForDeleteView; // Shows tracksToDelete
    IBOutlet NSTableView*           onDeviceView;           // Shows tracksOnDevice
    NSMutableDictionary*            players;                // Info dictionaries for the different players we support.
    IBOutlet NSPopUpButton*         playerPopUp;            // Shows players.
    IBOutlet NSProgressIndicator*   progress;               // Progress bar to show we're busy.
    IBOutlet NSTextField*           status;                 // Status text next to progress bar.
    IBOutlet UKFilePathView*        drivePath;              // Path of the MP3 player's volume.
    NSMutableArray*                 errorList;              // Dictionaries describing errors that occurred during sync.
    IBOutlet NSTableView*           errorListView;          // List view showing log of any errors that occurred during sync.
    NSMutableDictionary*            prevPlaylistState;      // State of playlists we're asked to keep synced last time we synced. Playlist names are keys, values are dictionaries: Track IDs -> NSArray of track IDs from last time, copy -> Copy flag for this playlist.
}

-(void) copyOverFiles: (id)sender;                      // Sync MP3 player with checkmarked items in list.
-(BOOL) copyOneTrack: (NSDictionary*)track;             // Called by copyOverFiles: for each track to copy to MP3 player.
-(void) deleteOneTrack: (NSDictionary*)track;           // Called by copyOverFiles: for each track to delete from MP3 player.

-(void) markExistingFiles: (id)sender;                  // Checkmark all tracks in the library that exist on the MP3 player.
-(void) markExistingFilesInLibrary; 

-(void) markOneTrackIfItExists: (NSDictionary*)track;   // Checkmark the specified track if it exists on the MP3 player (Called by markExistingFiles:).
-(void) markChangedFilesInLibraries;

-(void) playerSettingsChanged: (id)sender;              // Called by playerPopUp to indicate user picked a different player.
-(void) playerDriveChanged: (id)sender;                 // Called by drivePath to indicate user picked a different volume.

-(void) refreshSizeDisplay;                             // Refresh the status bar with size info (or status msg if no player available).

-(void) closeErrorSheet: (id)sender;

-(void) ejectMP3PlayerVolume: (id)sender;

-(NSString*)    pathForTrack: (NSDictionary*)track;
-(void)         addTrackToPlayer: (NSDictionary*)track;
-(void)         removeTrackFromPlayer: (NSDictionary*)track;

@end
