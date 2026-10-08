/* layout.m: the bar's layout with a theme's margin and spacing: tabs
   start after the margin, are spaced apart, and the "+" button ends a
   margin before the bar's end, a spacing after the last tab. Needs a
   display (a private Xvfb, no window manager needed); skips without one.

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

/* As a theme would: GSTheme then keeps these instead of the defaults. */
@implementation GSTheme (LayoutTest)
- (CGFloat) windowTabBarMarginForWindow: (NSWindow *)window
{
  return 6.0;
}
- (CGFloat) windowTabSpacingForWindow: (NSWindow *)window
{
  return 5.0;
}
@end

@interface PlusResponder : NSObject
@end

@implementation PlusResponder
- (void) newWindowForTab: (id)sender
{
}
@end

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

static void
spin (void)
{
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("the bar's margin and spacing")
    {
      NSWindow *a, *b, *c;
      GSWindowTabBarView *bar;
      NSRect t0, t1, t2, plus;
      CGFloat width;

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
      spin ();
      bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (c);
      width = NSWidth ([bar bounds]);
      PASS (bar != nil && [bar numberOfTabs] == 3, "three tabs in the bar");

      t0 = [bar rectForTabAtIndex: 0];
      t1 = [bar rectForTabAtIndex: 1];
      t2 = [bar rectForTabAtIndex: 2];
      PASS (fabs (NSMinX (t0) - 6.0) < 0.01, "the first tab starts after the margin");
      PASS (fabs (NSMinX (t1) - (NSMaxX (t0) + 5.0)) < 0.01, "tabs are spaced apart");
      /* Tab widths are whole pixels: up to a pixel a tab short. */
      PASS ((width - 6.0) - NSMaxX (t2) >= 0.0 && (width - 6.0) - NSMaxX (t2) < 3.0,
            "with no \"+\", the last tab ends a margin before the bar's end");

      [NSApp setDelegate: (id)[PlusResponder new]];
      plus = [bar newTabButtonRect];
      t2 = [bar rectForTabAtIndex: 2];
      PASS (NSIsEmptyRect (plus) == NO && fabs (NSMaxX (plus) - (width - 6.0)) < 0.01,
            "the \"+\" ends a margin before the bar's end");
      PASS (NSMinX (plus) - (NSMaxX (t2) + 5.0) >= 0.0
            && NSMinX (plus) - (NSMaxX (t2) + 5.0) < 3.0,
            "a spacing after the last tab");
    }
  END_SET ("the bar's margin and spacing")

  [pool release];
  return 0;
}
