/* tabbing_glue.m: the tabbing API on real NSWindows: installing, automatic
   tabbing, the Windows menu's path (ordering a hidden tab in), titles,
   the reserved row, toggling the bar, closing, Disallowed and panels,
   merging, moving a tab out, validation, the bar's mouse handling, and
   (on X11) the window manager's maximized state going with the selected
   tab, and the group's frame kept when a tab's in-window menu bar comes
   or goes.
   Needs a display (a private Xvfb, no window manager needed); skips
   without one.

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
#import <GNUstepGUI/GSDisplayServer.h>

#if !defined(_WIN32) && defined(__has_include)
#if __has_include(<X11/Xlib.h>)
#define HAVE_X11 1
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>

/* Xlib from libs-back's X11 server, looked up as the code does. */
static Atom (*internAtom)(Display *, const char *, Bool);
static int (*getWindowProperty)(Display *, Window, Atom, long, long, Bool,
  Atom, Atom *, int *, unsigned long *, unsigned long *, unsigned char **);
static int (*changeProperty)(Display *, Window, Atom, Atom, int, int,
  const unsigned char *, int);
static int (*xFree)(void *);

static Display *
x11Display (void)
{
  GSDisplayServer *server = GSCurrentServer ();

  if (NSClassFromString (@"XGServer") == Nil
    || [server isKindOfClass: NSClassFromString (@"XGServer")] == NO)
    {
      return NULL;
    }
  internAtom = dlsym (RTLD_DEFAULT, "XInternAtom");
  getWindowProperty = dlsym (RTLD_DEFAULT, "XGetWindowProperty");
  changeProperty = dlsym (RTLD_DEFAULT, "XChangeProperty");
  xFree = dlsym (RTLD_DEFAULT, "XFree");
  if (internAtom == NULL || getWindowProperty == NULL
    || changeProperty == NULL || xFree == NULL)
    {
      return NULL;
    }
  return (Display *)[server serverDevice];
}

static Window
x11Window (NSWindow *window)
{
  return (Window)(uintptr_t)[GSCurrentServer () windowDevice: [window windowNumber]];
}

/* Sets the window's _NET_WM_STATE as a window manager would: maximized
   both ways, or nothing. */
static void
setMaximized (Display *display, NSWindow *window, BOOL flag)
{
  Atom atoms[2];

  atoms[0] = internAtom (display, "_NET_WM_STATE_MAXIMIZED_VERT", False);
  atoms[1] = internAtom (display, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
  changeProperty (display, x11Window (window),
                  internAtom (display, "_NET_WM_STATE", False), XA_ATOM, 32,
                  PropModeReplace, (const unsigned char *)atoms, flag ? 2 : 0);
}

/* How many of the two maximized atoms the window's _NET_WM_STATE has. */
static int
maximizedAtoms (Display *display, NSWindow *window)
{
  Atom vertical = internAtom (display, "_NET_WM_STATE_MAXIMIZED_VERT", False);
  Atom horizontal = internAtom (display, "_NET_WM_STATE_MAXIMIZED_HORZ", False);
  Atom type;
  int format, found = 0;
  unsigned long count, remaining, i;
  unsigned char *data = NULL;

  if (getWindowProperty (display, x11Window (window),
                         internAtom (display, "_NET_WM_STATE", False), 0, 32,
                         False, XA_ATOM, &type, &format, &count, &remaining,
                         &data) == Success && data != NULL)
    {
      for (i = 0; i < count; i++)
        {
          Atom atom = ((Atom *)data)[i];

          found += (atom == vertical || atom == horizontal) ? 1 : 0;
        }
      xFree (data);
    }
  return found;
}
#endif
#endif

@interface NewTabResponder : NSObject
{
@public
  int requests;
}
@end

@implementation NewTabResponder
- (void) newWindowForTab: (id)sender
{
  NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 300, 200)
                                            styleMask: NSTitledWindowMask | NSClosableWindowMask
                                              backing: NSBackingStoreBuffered
                                                defer: NO];
  requests++;
  [w setTitle: @"From plus"];
  [w setTabbingIdentifier: @"doc"];
  [w makeKeyAndOrderFront: nil];
}
@end

static NSWindow *
makeWindow (NSString *title, NSWindowTabbingMode mode)
{
  NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                            styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                       | NSResizableWindowMask
                                              backing: NSBackingStoreBuffered
                                                defer: NO];
  [w setTitle: title];
  [w setTabbingIdentifier: @"doc"];
  [w setTabbingMode: mode];
  [w setReleasedWhenClosed: NO];
  return w;
}

static void
spin (void)
{
  [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
}

static void
clickBar (NSWindow *window, NSPoint point)
{
  GSWindowTabBarView *bar = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (window);
  NSPoint inWindow = [bar convertPoint: point toView: nil];
  NSEvent *down = [NSEvent mouseEventWithType: NSLeftMouseDown location: inWindow
                                modifierFlags: 0 timestamp: 0
                                 windowNumber: [window windowNumber] context: nil
                                  eventNumber: 0 clickCount: 1 pressure: 1.0];
  NSEvent *up = [NSEvent mouseEventWithType: NSLeftMouseUp location: inWindow
                              modifierFlags: 0 timestamp: 0
                               windowNumber: [window windowNumber] context: nil
                                eventNumber: 0 clickCount: 1 pressure: 1.0];

  /* The bar tracks a button press until the release; an earlier click's
     release, not taken by a tab (a press selects it at once), would be
     taken first. */
  while ([NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask
                            untilDate: [NSDate distantPast]
                               inMode: NSEventTrackingRunLoopMode
                              dequeue: YES] != nil)
    {
    }
  [NSApp postEvent: up atStart: NO];
  [bar mouseDown: down];
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("window tabbing on NSWindow")
    {
      NSWindow *a, *b, *c, *d, *e;
      NSPanel *panel;
      NSMenuItem *item;
      CGFloat bar;
      NSRect content;
      NewTabResponder *responder;

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

      PASS (GSWindowTabbingInstall (), "installs");
      PASS (GSWindowTabbingInstall (), "and a second call does nothing");
      PASS ([NSWindow instancesRespondToSelector: @selector(addTabbedWindow:ordered:)]
            && [NSWindow respondsToSelector: @selector(allowsAutomaticWindowTabbing)],
            "NSWindow has the API");
      PASS ([[GSTheme theme] respondsToSelector: @selector(drawWindowTab:inRect:state:window:)],
            "GSTheme has the default drawing");

      a = makeWindow (@"A", NSWindowTabbingModePreferred);
      b = makeWindow (@"B", NSWindowTabbingModePreferred);
      PASS ([a tabbedWindows] == nil, "a window on its own has no tabbedWindows");
      PASS ([[[a tabGroup] windows] count] == 1, "but a group with itself in it");

      [a makeKeyAndOrderFront: nil];
      spin ();
      content = [[a contentView] frame];
      [b makeKeyAndOrderFront: nil];
      spin ();
      PASS ([[a tabbedWindows] count] == 2 && [a tabGroup] == [b tabGroup],
            "a Preferred window ordered in joins the key window's group");
      PASS ([b isVisible] && [a isVisible] == NO, "and only the new tab is on screen");
      PASS (NSEqualRects ([b frame], [a frame]), "at the group's frame");
      bar = [[GSTheme theme] windowTabBarHeightForWindow: b];
      PASS (GSWindowTabBarViewForWindow (b) != nil, "the tab bar shows");
      PASS (fabs (NSHeight ([[b contentView] frame]) - (NSHeight (content) - bar)) < 0.5,
            "and the content gives up the bar's height");

      [a makeKeyAndOrderFront: nil];
      spin ();
      PASS ([[a tabGroup] selectedWindow] == a && [a isVisible] && [b isVisible] == NO,
            "ordering a hidden tab in (the Windows menu) selects it");

      {
        NSMenu *windowsMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Window"]);
        NSArray *items;
        BOOL hasA = NO, hasB = NO;
        NSUInteger i;

        [NSApp setWindowsMenu: windowsMenu];
        [NSApp addWindowsItem: a title: [a title] filename: NO];
        [NSApp addWindowsItem: b title: [b title] filename: NO];
        items = [windowsMenu itemArray];
        for (i = 0; i < [items count]; i++)
          {
            id target = [[items objectAtIndex: i] target];

            hasA = hasA || target == a;
            hasB = hasB || target == b;
          }
        PASS (hasA && hasB, "the Windows menu lists every tab, hidden ones too");
      }

      [b setTitle: @"Renamed"];
      PASS_EQUAL ([[b tab] title], @"Renamed", "a tab's title follows -setTitle:");
      [b setTitleWithRepresentedFilename: @"/tmp/Notes.txt"];
      PASS_EQUAL ([[b tab] title], @"Notes.txt",
                  "and -setTitleWithRepresentedFilename:, as the file's name");

      item = AUTORELEASE ([[NSMenuItem alloc] initWithTitle: @"Next"
                                                     action: @selector(selectNextTab:)
                                              keyEquivalent: @""]);
      PASS ([a validateMenuItem: item], "Show Next Tab is enabled with two tabs");
      [item setAction: @selector(toggleTabBar:)];
      PASS ([a validateMenuItem: item] && [[item title] isEqual: @"Hide Tab Bar"],
            "Hide Tab Bar while the bar shows");

      [a toggleTabBar: nil];
      spin ();
      PASS (GSWindowTabBarViewForWindow (a) == nil
            && fabs (NSHeight ([[a contentView] frame]) - NSHeight (content)) < 0.5,
            "toggling hides the bar and gives the row back");
      [a toggleTabBar: nil];
      spin ();

      [a selectNextTab: nil];
      spin ();
      PASS ([[a tabGroup] selectedWindow] == b, "selectNextTab:");

      [b close];
      spin ();
      PASS ([a isVisible] && [a tabbedWindows] == nil,
            "closing the selected tab shows its neighbour");
      PASS (GSWindowTabBarViewForWindow (a) == nil, "and with one window the bar goes");

      c = makeWindow (@"C", NSWindowTabbingModeDisallowed);
      [c makeKeyAndOrderFront: nil];
      spin ();
      PASS ([c tabbedWindows] == nil && [c isVisible], "a Disallowed window stays on its own");
      [c close];
      [a makeKeyAndOrderFront: nil];
      spin ();

      panel = [[NSPanel alloc] initWithContentRect: NSMakeRect (0, 0, 200, 100)
                                         styleMask: NSTitledWindowMask
                                           backing: NSBackingStoreBuffered
                                             defer: NO];
      [panel setTabbingIdentifier: @"doc"];
      [panel setTabbingMode: NSWindowTabbingModePreferred];
      [panel orderFront: nil];
      spin ();
      PASS ([panel tabbedWindows] == nil, "panels aren't tabbed");
      [panel close];

      d = makeWindow (@"D", NSWindowTabbingModeAutomatic);
      e = makeWindow (@"E", NSWindowTabbingModeAutomatic);
      [d orderFront: nil];
      [e orderFront: nil];
      spin ();
      PASS ([d tabbedWindows] == nil && [e tabbedWindows] == nil,
            "Automatic windows don't join by default (no AppleWindowTabbingMode always)");
      [a makeKeyAndOrderFront: nil];
      [a mergeAllWindows: nil];
      spin ();
      PASS ([[a tabbedWindows] count] == 3 && [[a tabGroup] selectedWindow] == a,
            "mergeAllWindows: gathers them, the window asking stays selected");
      PASS ([d isVisible] == NO && [e isVisible] == NO, "the others become hidden tabs");

      [a moveTabToNewWindow: nil];
      spin ();
      PASS ([a tabbedWindows] == nil && [a isVisible] && [[d tabbedWindows] count] == 2,
            "moveTabToNewWindow: takes the tab out to a window of its own");
      PASS ([d isVisible] || [e isVisible], "and the group shows its next tab");

      /* The bar's mouse handling, in the group of D and E. */
      {
        NSWindow *shown = [d isVisible] ? d : e;
        NSWindow *other = (shown == d) ? e : d;
        GSWindowTabBarView *view = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (shown);
        NSUInteger index = [[[shown tabGroup] windows] indexOfObjectIdenticalTo: other];
        NSRect tabRect = [view rectForTabAtIndex: index];

        PASS (NSIsEmptyRect ([view newTabButtonRect]),
              "no \"+\" while nothing responds to -newWindowForTab:");
        clickBar (shown, NSMakePoint (NSMidX (tabRect), NSMidY (tabRect)));
        spin ();
        PASS ([[shown tabGroup] selectedWindow] == other && [other isVisible],
              "a click on a tab selects it");

        responder = [NewTabResponder new];
        [NSApp setDelegate: (id)responder];
        view = (GSWindowTabBarView *)GSWindowTabBarViewForWindow (other);
        PASS (NSIsEmptyRect ([view newTabButtonRect]) == NO,
              "a \"+\" when something does");
        clickBar (other, NSMakePoint (NSMidX ([view newTabButtonRect]),
                                      NSMidY ([view newTabButtonRect])));
        spin ();
        PASS (responder->requests == 1, "the \"+\" asks for a new window");
        PASS ([[other tabbedWindows] count] == 3, "which joins the group");
      }
    }
  END_SET ("window tabbing on NSWindow")

  START_SET ("in-window menu bars")
    {
      NSWindow *a, *b, *c;
      NSView *decoration;
      NSMenuView *menuView;
      NSRect frame, content;
      CGFloat height;

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
      a = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                      styleMask: NSTitledWindowMask | NSClosableWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
      b = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                      styleMask: NSTitledWindowMask | NSClosableWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
      [a setTabbingIdentifier: @"menus"];
      [b setTabbingIdentifier: @"menus"];
      [a setReleasedWhenClosed: NO];
      [b setReleasedWhenClosed: NO];
      [a makeKeyAndOrderFront: nil];

      /* On its own, a window grows by the bar, as libs-gui has it. */
      decoration = [[a contentView] superview];
      frame = [a frame];
      menuView = AUTORELEASE ([[NSMenuView alloc] initWithFrame: NSMakeRect (0, 0, 400, 20)]);
      [(GSWindowDecorationView *)decoration addMenuView: menuView];
      height = NSHeight ([a frame]) - NSHeight (frame);
      PASS (height > 0.0, "a window on its own grows by an in-window menu bar");

      /* A new tab, given the group's frame (with a's bar) before it has a
         bar of its own, as under NSWindows95InterfaceStyle, where the bar
         comes when it becomes key. */
      [a addTabbedWindow: b ordered: NSWindowAbove];
      [[a tabGroup] setSelectedWindow: b];
      frame = [b frame];
      content = [[b contentView] frame];
      decoration = [[b contentView] superview];
      menuView = AUTORELEASE ([[NSMenuView alloc] initWithFrame: NSMakeRect (0, 0, 400, 20)]);
      [(GSWindowDecorationView *)decoration addMenuView: menuView];
      PASS (NSEqualRects ([b frame], frame),
            "a tab given a menu bar after it is selected keeps the group's frame");
      PASS (fabs (NSHeight ([[b contentView] frame]) - (NSHeight (content) - height)) < 0.5,
            "its content gives up the bar's row");

      /* And a third: the group stays the same size. */
      c = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                      styleMask: NSTitledWindowMask | NSClosableWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
      [c setTabbingIdentifier: @"menus"];
      [c setReleasedWhenClosed: NO];
      [b addTabbedWindow: c ordered: NSWindowAbove];
      [[a tabGroup] setSelectedWindow: c];
      decoration = [[c contentView] superview];
      menuView = AUTORELEASE ([[NSMenuView alloc] initWithFrame: NSMakeRect (0, 0, 400, 20)]);
      [(GSWindowDecorationView *)decoration addMenuView: menuView];
      PASS (NSEqualRects ([c frame], frame),
            "so each new tab leaves the group the size it was");
      [(GSWindowDecorationView *)decoration removeMenuView];
      PASS (NSEqualRects ([c frame], frame)
            && fabs (NSHeight ([[c contentView] frame]) - NSHeight (content)) < 0.5,
            "and one whose bar goes keeps it too, its content taking the row back");
      [c close];
      [b close];
      [a close];
    }
  END_SET ("in-window menu bars")

  START_SET ("maximized windows")
    {
#if defined(HAVE_X11)
      Display *display;
      NSWindow *a, *b;

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
      display = x11Display ();
      if (display == NULL)
        {
          SKIP ("not libs-back's X11 server")
        }
      GSWindowTabbingInstall ();
      [NSWindow setAllowsAutomaticWindowTabbing: NO];
      a = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                      styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                 | NSResizableWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
      b = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                      styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                 | NSResizableWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
      [a setTabbingIdentifier: @"zoom"];
      [b setTabbingIdentifier: @"zoom"];
      [a setReleasedWhenClosed: NO];
      [b setReleasedWhenClosed: NO];
      [a makeKeyAndOrderFront: nil];
      [a addTabbedWindow: b ordered: NSWindowAbove];
      [[a tabGroup] setSelectedWindow: a];

      /* No window manager runs here: the test sets the state on the
         shown window, as one would, and reads what the code gave the
         window it shows next. */
      setMaximized (display, a, YES);
      [[a tabGroup] setSelectedWindow: b];
      PASS (maximizedAtoms (display, b) == 2,
            "a tab selected in place of a maximized window is mapped maximized (_NET_WM_STATE)");
      setMaximized (display, b, NO);
      [[a tabGroup] setSelectedWindow: a];
      PASS (maximizedAtoms (display, a) == 0,
            "one selected in place of a window that isn't maximized loses the state it had");
      [b close];
      [a close];
#else
      SKIP ("no X11 headers")
#endif
    }
  END_SET ("maximized windows")

  [pool release];
  return 0;
}
