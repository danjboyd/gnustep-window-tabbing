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
      NSWindow *a, *b, *c, *d, *e;
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

      /* Along the bar: two slots to the right. */
      path[0] = fromTab (a, 0, 20.0, 0.0);
      path[1] = fromTab (a, 0, step, 0.0);
      path[2] = fromTab (a, 0, 2.0 * step, 2.0);
      dragTab (a, 0, path, 3, NO);
      PASS_EQUAL (titles ([[a tabGroup] windows]), ([NSArray arrayWithObjects: @"B", @"C", @"A", nil]),
                  "a tab dragged two slots along the bar is dropped there");
      PASS ([[a tabGroup] selectedWindow] == a && [a isVisible],
            "and stays selected, on screen");
      PASS ([GSWindowTabBarViewForWindow (a) isDraggingTab] == NO, "the drag is over");

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

      /* Onto a window of another kind: declined, a window of its own. */
      e = makeWindow (@"E", @"other", NSMakeRect (100, 50, 500, 250));
      [e orderFront: nil];
      spin ();
      path[0] = fromTab (c, 0, 20.0, 0.0);
      path[1] = fromTab (c, 0, 30.0, -80.0);
      path[2] = NSMakePoint (NSMidX ([e frame]), NSMaxY ([e frame]) - 10.0);
      dragTab (c, 0, path, 3, NO);
      PASS ([[[e tabGroup] windows] count] == 1 && [[[c tabGroup] windows] count] == 1
            && [c isVisible] && [[d tabGroup] selectedWindow] == d && [d isVisible],
            "dropped on a window with another tabbing identifier, it becomes a window of its own");
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
    }
  END_SET ("scrolling the bar")

  [pool release];
  return 0;
}
