/* tabbing_drag.m: dragging tabs and scrolling the bar.  A tab dragged
   along the bar takes the slot it is dropped in and stays selected;
   Escape cancels; a small move is a click; a tab pulled out of the bar
   becomes a window of its own under the pointer, or a tab of the window
   it is dropped on if the two can be tabbed together.  Tabs that don't
   fit scroll with the wheel, and the selected one is kept in sight.
   Posts its events, so it needs a display (an Xvfb, no window manager
   needed); skips without one.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
*/

#import "Testing.h"
#import <AppKit/AppKit.h>
#import "GSWindowTabbing.h"
#import "GSWindowTabBarView.h"

/* Black, with GSTheme's default scroll fade over its right half. */
@interface FadeView : NSView
@end

@implementation FadeView
- (void) drawRect: (NSRect)rect
{
  [[NSColor blackColor] set];
  NSRectFill ([self bounds]);
  [[GSTheme theme] drawWindowTabBarScrollFadeInRect: NSMakeRect (20, 0, 20, 20)
                                               edge: NSMaxXEdge
                                             window: [self window]];
}
@end

static NSWindow *
makeWindow (NSString *title, NSString *identifier, NSRect frame)
{
  NSWindow *w = [[NSWindow alloc] initWithContentRect: frame
                                            styleMask: NSTitledWindowMask | NSClosableWindowMask
                                              backing: NSBackingStoreBuffered
                                                defer: NO];
  [w setTitle: title];
  [w setTabbingIdentifier: identifier];
  [w setReleasedWhenClosed: NO];
  return w;
}

static void
spin (void)
{
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

static NSArray *
titles (NSArray *windows)
{
  NSMutableArray *a = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      [a addObject: [[windows objectAtIndex: i] title]];
    }
  return a;
}

static NSEvent *
mouse (NSEventType type, NSWindow *window, NSPoint inWindow)
{
  return [NSEvent mouseEventWithType: type location: inWindow
                       modifierFlags: 0 timestamp: 0
                        windowNumber: [window windowNumber] context: nil
                         eventNumber: 0 clickCount: 1 pressure: 1.0];
}

static NSEvent *
escape (NSWindow *window)
{
  return [NSEvent keyEventWithType: NSKeyDown location: NSZeroPoint
                     modifierFlags: 0 timestamp: 0
                      windowNumber: [window windowNumber] context: nil
                        characters: @"\e" charactersIgnoringModifiers: @"\e"
                         isARepeat: NO keyCode: 9];
}

/* Presses window's tab at index, drags the pointer through count screen
   points (escape first, if asked), and releases at the last one: the
   events are queued as a real drag's would be, and the bar's own
   tracking takes them. */
static void
dragTab (NSWindow *window, NSUInteger index, NSPoint *screen,
         NSUInteger count, BOOL cancel)
{
  GSWindowTabBarView *bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (window);
  NSRect tab = [bar convertRect: [bar rectForTabAtIndex: index] toView: nil];
  NSPoint start = NSMakePoint (NSMidX (tab) - 20.0, NSMidY (tab));
  NSUInteger i;

  while ([NSApp nextEventMatchingMask: NSAnyEventMask
                            untilDate: [NSDate distantPast]
                               inMode: NSEventTrackingRunLoopMode
                              dequeue: YES] != nil)
    {
    }
  for (i = 0; i < count; i++)
    {
      NSPoint point = [window convertScreenToBase: screen[i]];

      if (cancel && i == count - 1)
        {
          [NSApp postEvent: escape (window) atStart: NO];
        }
      [NSApp postEvent: mouse ((i == count - 1) ? NSLeftMouseUp : NSLeftMouseDragged,
                               window, point)
               atStart: NO];
    }
  [bar mouseDown: mouse (NSLeftMouseDown, window, start)];
  spin ();
}

/* The screen point dx, dy from the middle of window's tab at index. */
static NSPoint
fromTab (NSWindow *window, NSUInteger index, CGFloat dx, CGFloat dy)
{
  GSWindowTabBarView *bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (window);
  NSRect tab = [bar convertRect: [bar rectForTabAtIndex: index] toView: nil];

  return [window convertBaseToScreen:
    NSMakePoint (NSMidX (tab) - 20.0 + dx, NSMidY (tab) + dy)];
}

static NSEvent *
wheel (NSWindow *window, NSPoint inWindow, CGFloat deltaY)
{
  return [NSEvent mouseEventWithType: NSScrollWheel location: inWindow
                       modifierFlags: 0 timestamp: 0
                        windowNumber: [window windowNumber] context: nil
                         eventNumber: 0 clickCount: 1 pressure: 1.0
                        buttonNumber: 0 deltaX: 0.0 deltaY: deltaY deltaZ: 0.0];
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("dragging tabs")
    {
      NSWindow *a, *b, *c, *d, *e, *f, *g;
      NSPoint path[4];
      NSRect frame;
      CGFloat step;
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
      [NSWindow setAllowsAutomaticWindowTabbing: NO];

      a = makeWindow (@"A", @"doc", NSMakeRect (100, 400, 600, 300));
      b = makeWindow (@"B", @"doc", NSMakeRect (100, 400, 600, 300));
      c = makeWindow (@"C", @"doc", NSMakeRect (100, 400, 600, 300));
      [a makeKeyAndOrderFront: nil];
      [a addTabbedWindow: b ordered: NSWindowAbove];
      [b addTabbedWindow: c ordered: NSWindowAbove];
      [[a tabGroup] setSelectedWindow: a];
      spin ();
      PASS_EQUAL (titles ([[a tabGroup] windows]), ([NSArray arrayWithObjects: @"A", @"B", @"C", nil]),
                  "three tabs, A selected");
      bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (a);
      step = [bar tabWidth] + [bar spacing];

      /* A gap for a tab from another window: the tabs from its slot on
         move one along, and four slots share the bar; then it closes. */
      {
        NSRect first = [bar rectForTabAtIndex: 0];
        CGFloat width = [bar tabWidth];

        [bar setDropGapSlot: 1];
        PASS ([bar dropGapSlot] == 1
              && fabs (NSMinX ([bar rectForTabAtIndex: 1])
                       - (NSMinX (first) + 2.0 * ([bar tabWidth] + [bar spacing]))) < 0.5
              && fabs (NSMinX ([bar rectForTabAtIndex: 0]) - NSMinX (first)) < 0.5,
              "a drop gap at slot 1 moves the second and third tabs one slot along");
        PASS ([bar tabWidth] <= width,
              "and the bar lays out four slots");
        [bar setDropGapSlot: -1];
        PASS ([bar dropGapSlot] == -1 && fabs ([bar tabWidth] - width) < 0.5,
              "closing it puts the tabs back");
      }

      /* Along the bar: two slots to the right. */
      path[0] = fromTab (a, 0, 20.0, 0.0);
      path[1] = fromTab (a, 0, step, 0.0);
      path[2] = fromTab (a, 0, 2.0 * step, 2.0);
      dragTab (a, 0, path, 3, NO);
      PASS_EQUAL (titles ([[a tabGroup] windows]), ([NSArray arrayWithObjects: @"B", @"C", @"A", nil]),
                  "a tab dragged two slots along the bar is dropped there");
      PASS ([[a tabGroup] selectedWindow] == a && [a isVisible],
            "and stays selected, on screen");
      PASS ([(GSWindowTabBarView *)GSWindowTabBarViewForWindow (a) isDraggingTab] == NO,
            "the drag is over");

      /* Escape: back where it was. */
      path[0] = fromTab (a, 2, -20.0, 0.0);
      path[1] = fromTab (a, 2, -2.0 * step, 0.0);
      dragTab (a, 2, path, 2, YES);
      PASS_EQUAL (titles ([[a tabGroup] windows]), ([NSArray arrayWithObjects: @"B", @"C", @"A", nil]),
                  "Escape cancels a drag");

      /* Under the drag threshold: a click, which selects. */
      path[0] = fromTab (a, 0, 3.0, 2.0);
      dragTab (a, 0, path, 1, NO);
      PASS ([[a tabGroup] selectedWindow] == b
            && [titles ([[a tabGroup] windows]) isEqual:
                         ([NSArray arrayWithObjects: @"B", @"C", @"A", nil])],
            "a move under the drag threshold is a click: it selects, nothing moves");

      /* Pulled down, but less than 32 points past the bar's edge: still in
         it, one slot along; then back. */
      {
        GSWindowTabBarView *bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (b);
        NSRect barRect = [bar convertRect: [bar bounds] toView: nil];
        NSRect tab = [bar convertRect: [bar rectForTabAtIndex: 0] toView: nil];
        CGFloat below = NSMinY (barRect) - NSMidY (tab);

        path[0] = fromTab (b, 0, 20.0, 0.0);
        path[1] = fromTab (b, 0, step, below - 28.0);
        dragTab (b, 0, path, 2, NO);
        PASS_EQUAL (titles ([[b tabGroup] windows]),
                    ([NSArray arrayWithObjects: @"C", @"B", @"A", nil]),
                    "a tab pulled 28 points below the bar stays in it");
        path[0] = fromTab (b, 1, -20.0, 0.0);
        path[1] = fromTab (b, 1, -step, 0.0);
        dragTab (b, 1, path, 2, NO);
      }

      /* Out of the bar, into empty space: a window of its own. */
      frame = [b frame];
      path[0] = fromTab (b, 0, 20.0, 0.0);
      path[1] = fromTab (b, 0, 30.0, -80.0);
      path[2] = fromTab (b, 0, 40.0, -200.0);
      dragTab (b, 0, path, 3, NO);
      PASS ([[[b tabGroup] windows] count] == 1 && [b isVisible]
            && [[[c tabGroup] windows] count] == 2,
            "a tab pulled out of the bar becomes a window of its own");
      PASS (fabs (NSMinY ([b frame]) - (NSMinY (frame) - 200.0)) < 2.0
            && fabs (NSMinX ([b frame]) - (NSMinX (frame) + 40.0)) < 2.0,
            "under the pointer, where it was pressed");

      /* Onto a window that can take it: one of its tabs. */
      d = makeWindow (@"D", @"doc", NSMakeRect (800, 100, 500, 250));
      [d orderFront: nil];
      spin ();
      path[0] = fromTab (c, 0, 20.0, 0.0);
      path[1] = fromTab (c, 0, 30.0, -80.0);
      path[2] = NSMakePoint (NSMidX ([d frame]), NSMaxY ([d frame]) - 10.0);
      dragTab (c, 0, path, 3, NO);
      PASS_EQUAL (titles ([[d tabGroup] windows]), ([NSArray arrayWithObjects: @"D", @"C", nil]),
                  "a tab dropped on another window's title joins its tabs");
      PASS ([[d tabGroup] selectedWindow] == c && [c isVisible] && [d isVisible] == NO,
            "as its selected tab");
      PASS ([[[a tabGroup] windows] count] == 1 && [a isVisible],
            "its old group's other tab is shown in its place");

      /* Onto a window of another kind, clear of the others: declined, a
         window of its own. */
      e = makeWindow (@"E", @"other", NSMakeRect (800, 600, 500, 250));
      [e orderFront: nil];
      spin ();
      path[0] = fromTab (c, 0, 20.0, 0.0);
      path[1] = fromTab (c, 0, 30.0, -80.0);
      path[2] = NSMakePoint (NSMidX ([e frame]), NSMaxY ([e frame]) - 10.0);
      dragTab (c, 0, path, 3, NO);
      PASS ([[[e tabGroup] windows] count] == 1,
            "a window with another tabbing identifier declines a dropped tab");
      PASS ([[[c tabGroup] windows] count] == 1 && [c isVisible],
            "which becomes a window of its own");
      PASS ([[d tabGroup] selectedWindow] == d && [d isVisible],
            "its old group's other tab is shown in its place");

      /* Onto another window's tab bar: in the slot under the pointer, and
         the gap opened there for it closes on the drop. */
      f = makeWindow (@"F", @"doc", NSMakeRect (100, 400, 600, 300));
      g = makeWindow (@"G", @"doc", NSMakeRect (800, 100, 500, 250));
      [b addTabbedWindow: f ordered: NSWindowAbove];
      [[b tabGroup] setSelectedWindow: f];
      [d addTabbedWindow: g ordered: NSWindowAbove];
      [[d tabGroup] setSelectedWindow: d];
      spin ();
      {
        GSWindowTabBarView *target = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (d);
        NSRect slot = [target convertRect: [target rectForTabAtIndex: 1] toView: nil];

        path[0] = fromTab (f, 1, 20.0, 0.0);
        path[1] = fromTab (f, 1, 30.0, -80.0);
        path[2] = [d convertBaseToScreen: NSMakePoint (NSMinX (slot) + 5.0, NSMidY (slot))];
        dragTab (f, 1, path, 3, NO);
        PASS_EQUAL (titles ([[d tabGroup] windows]),
                    ([NSArray arrayWithObjects: @"D", @"F", @"G", nil]),
                    "a tab dropped on another window's tab bar takes the slot under the pointer");
        PASS ([target dropGapSlot] == -1
              && [(GSWindowTabBarView *)GSWindowTabBarViewForWindow (f) dropGapSlot] == -1,
              "and the gap opened for it is closed");
      }
    }
  END_SET ("dragging tabs")

  START_SET ("scrolling the bar")
    {
      NSWindow *first, *window = nil;
      GSWindowTabBarView *bar;
      NSRect tabs;
      CGFloat offset;
      NSUInteger i;

      first = makeWindow (@"T0", @"many", NSMakeRect (100, 400, 500, 300));
      [first makeKeyAndOrderFront: nil];
      window = first;
      for (i = 1; i < 9; i++)
        {
          NSWindow *next = makeWindow ([NSString stringWithFormat: @"T%lu", (unsigned long)i],
                                       @"many", NSMakeRect (100, 400, 500, 300));

          /* Each after the last: the last added, selected, is at the end. */
          [window addTabbedWindow: next ordered: NSWindowAbove];
          window = next;
        }
      spin ();
      bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow ([[first tabGroup] selectedWindow]);
      tabs = [bar tabsRect];
      PASS ([bar maximumScrollOffset] > 0.0, "nine tabs at their minimum width don't fit: the bar scrolls");
      i = [[[first tabGroup] windows] indexOfObjectIdenticalTo: [[first tabGroup] selectedWindow]];
      PASS (NSMinX ([bar rectForTabAtIndex: i]) >= NSMinX (tabs) - 0.5
            && NSMaxX ([bar rectForTabAtIndex: i]) <= NSMaxX (tabs) + 0.5,
            "the selected tab is scrolled into sight");
      offset = [bar scrollOffset];
      [bar scrollWheel: wheel ([bar window], [bar convertPoint: NSMakePoint (NSMidX (tabs), 10.0) toView: nil], 1.0)];
      PASS ([bar scrollOffset] < offset, "the wheel scrolls the tabs");
      PASS (fabs ((offset - [bar scrollOffset])
                  - MIN (offset, pow (NSWidth (tabs), 2.0 / 3.0))) < 0.5,
            "one notch as far as GTK's: the visible width to the power 2/3");
      [bar scrollWheel: wheel ([bar window], [bar convertPoint: NSMakePoint (NSMidX (tabs), 10.0) toView: nil], 100.0)];
      PASS ([bar scrollOffset] == 0.0, "but no further than the first tab");
      /* The last tab is out of sight now; select the first, then it. */
      [[first tabGroup] setSelectedWindow: first];
      spin ();
      [[first tabGroup] setSelectedWindow: window];
      spin ();
      bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (window);
      i = [[[first tabGroup] windows] indexOfObjectIdenticalTo: window];
      PASS (NSMaxX ([bar rectForTabAtIndex: i]) <= NSMaxX ([bar tabsRect]) + 0.5
            && [bar scrollOffset] > 0.0,
            "selecting a tab out of sight scrolls to it");
      PASS ([bar tabIndexAtPoint: NSMakePoint (NSMinX ([bar tabsRect]) - 1.0, 10.0)] == -1,
            "tabs scrolled out of the tabs' area can't be clicked");

      /* The first tab, dragged past the bar's right end and held there:
         the bar scrolls under it, so it can go to a slot that was out of
         sight. */
      [[first tabGroup] setSelectedWindow: first];
      spin ();
      bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (first);
      tabs = [bar tabsRect];
      {
        NSPoint drag[12];
        NSUInteger visible = (NSUInteger)floor ((NSWidth (tabs) + [bar spacing])
                                                / ([bar tabWidth] + [bar spacing]));
        NSPoint end = [first convertBaseToScreen:
          [bar convertPoint: NSMakePoint (NSMaxX (tabs) + 40.0, NSMidY (tabs)) toView: nil]];

        PASS ([bar scrollOffset] == 0.0 && visible < 9, "the first tab selected, the bar at its start");
        drag[0] = fromTab (first, 0, 20.0, 0.0);
        for (i = 1; i < 12; i++)
          {
            drag[i] = end;
          }
        dragTab (first, 0, drag, 12, NO);
        PASS ([[[first tabGroup] windows] indexOfObjectIdenticalTo: first] >= visible,
              "a tab held past the bar's end scrolls it, and drops in a slot that was out of sight");
      }

      /* GSTheme's fade, over black: controlColor at the edge, clear
         inwards. */
      {
        FadeView *view = [[FadeView alloc] initWithFrame: NSMakeRect (0, 0, 40, 20)];
        NSBitmapImageRep *rep;
        NSColor *control = [[NSColor controlColor]
          colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        NSColor *edge, *middle, *inside, *black;

        [[first contentView] addSubview: view];
        [first display];
        rep = [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
        [view cacheDisplayInRect: [view bounds] toBitmapImageRep: rep];
        black = [[rep colorAtX: 5 y: 10] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        inside = [[rep colorAtX: 20 y: 10] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        middle = [[rep colorAtX: 30 y: 10] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        edge = [[rep colorAtX: 39 y: 10] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
        PASS (fabs ([edge redComponent] - [control redComponent]) < 0.05
              && fabs ([edge blueComponent] - [control blueComponent]) < 0.05
              && [black redComponent] < 0.05 && [inside redComponent] < 0.1
              && [middle redComponent] > 0.15
              && [middle redComponent] < [control redComponent] - 0.15,
              "GSTheme's scroll fade draws the bar's colour at the edge, clear inwards");
        [view removeFromSuperview];
        [view release];
      }
    }
  END_SET ("scrolling the bar")

  [pool release];
  return 0;
}
