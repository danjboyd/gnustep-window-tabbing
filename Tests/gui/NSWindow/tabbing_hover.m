/* tabbing_hover.m: the bar follows the pointer: moved onto a tab, that tab is
   hovered (GNUstep gives the entered event in the view's coordinates);
   moved to the next tab, that one is; the tab after a selected or hovered
   tab says so in its state. Warps the pointer, so it needs a private
   display (an Xvfb, no window manager needed); skips without one.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
*/

#import "Testing.h"
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#import "GSWindowTabbing.h"
#import "GSWindowTabBarView.h"

static NSWindow *
makeWindow (NSString *title)
{
  NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 500, 300)
                                            styleMask: NSTitledWindowMask | NSClosableWindowMask
                                              backing: NSBackingStoreBuffered
                                                defer: NO];
  [w setTitle: title];
  [w setTabbingIdentifier: @"doc"];
  [w setTabbingMode: NSWindowTabbingModePreferred];
  [w setReleasedWhenClosed: NO];
  return w;
}

/* Hands the app the display's events for a moment, as -run would. */
static void
spin (void)
{
  NSDate *until = [NSDate dateWithTimeIntervalSinceNow: 0.3];
  NSEvent *event;

  while ((event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                     untilDate: until
                                        inMode: NSDefaultRunLoopMode
                                       dequeue: YES]) != nil)
    {
      [NSApp sendEvent: event];
    }
}

/* Moves the pointer to the middle of the bar's tab at index. */
static void
pointAtTab (GSWindowTabBarView *bar, NSUInteger index)
{
  NSRect tab = [bar convertRect: [bar rectForTabAtIndex: index] toView: nil];
  NSPoint point = NSMakePoint (NSMidX (tab) - 20.0, NSMidY (tab));

  point = [[bar window] convertBaseToScreen: point];
  [GSServerForWindow ([bar window]) setMouseLocation: point onScreen: 0];
  spin ();
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("hover")
    {
      NSWindow *a, *b, *c;
      GSWindowTabBarView *bar;

      if (getenv ("DISPLAY") == NULL)
        {
          SKIP ("no display")
        }
      NS_DURING
        {
          [NSApplication sharedApplication];
        }
      NS_HANDLER
        {
          SKIP ("no display server")
        }
      NS_ENDHANDLER

      GSWindowTabbingInstall ();
      a = makeWindow (@"A");
      b = makeWindow (@"B");
      c = makeWindow (@"C");
      [a makeKeyAndOrderFront: nil];
      spin ();
      [a addTabbedWindow: b ordered: NSWindowAbove];
      [b addTabbedWindow: c ordered: NSWindowAbove];
      [[a tabGroup] setSelectedWindow: a];
      spin ();
      bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (a);
      PASS (bar != nil && [bar numberOfTabs] == 3, "three tabs in the bar");

      [GSServerForWindow (a) setMouseLocation: NSMakePoint (5, 5) onScreen: 0];
      spin ();
      PASS (([bar stateForTabAtIndex: 1] & GSWindowTabHovered) == 0,
            "away from the bar, no tab is hovered");
      PASS (([bar stateForTabAtIndex: 1] & GSWindowTabPreviousHighlighted) != 0,
            "the tab after the selected one says so");
      PASS (([bar stateForTabAtIndex: 2] & GSWindowTabPreviousHighlighted) == 0,
            "the tab after an unselected, unhovered one doesn't");

      pointAtTab (bar, 1);
      PASS (([bar stateForTabAtIndex: 1] & GSWindowTabHovered) != 0,
            "moved onto a tab, the tab is hovered");
      PASS (([bar stateForTabAtIndex: 2] & GSWindowTabPreviousHighlighted) != 0,
            "the tab after the hovered one says so");

      pointAtTab (bar, 2);
      PASS (([bar stateForTabAtIndex: 2] & GSWindowTabHovered) != 0
            && ([bar stateForTabAtIndex: 1] & GSWindowTabHovered) == 0,
            "moved to the next tab, that tab is hovered instead");

      [GSServerForWindow (a) setMouseLocation: NSMakePoint (5, 5) onScreen: 0];
      spin ();
      PASS (([bar stateForTabAtIndex: 2] & GSWindowTabHovered) == 0,
            "moved off the bar, no tab is hovered");
    }
  END_SET ("hover")

  [pool release];
  return 0;
}
