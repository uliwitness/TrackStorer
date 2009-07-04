//
//  main.m
//  TrackStorer
//
//  Created by Uli Kusterer on 13.06.05.
//  Copyright M. Uli Kusterer 2005. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UKCustomWindowFrame.h"


int main(int argc, char *argv[])
{
    NSAutoreleasePool*  pool = [NSAutoreleasePool new];
    [UKCustomWindowFrame installCustomWindowFrame];
    [UKCustomWindowFrame setCustomWindowTextColor: [NSColor blackColor]];
    //[UKCustomWindowFrame setCustomWindowImage: [NSImage imageNamed: @"blue_gradient"]];
    [UKCustomWindowFrame setCustomWindowColor: [NSColor colorWithPatternImage: [NSImage imageNamed: @"blue_gradient"]]];
    [pool release];
    
    return NSApplicationMain(argc,  (const char **) argv);
}
