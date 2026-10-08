/* TabDemo: document windows as tabs, through Apple's API only.

   Copyright (C) 2026 Daniel Boyd

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   File > New Tab (Ctrl+T) and the tab bar's "+" ask for
   -newWindowForTab:, File > New Window (Ctrl+N) opens a window of its
   own, and the Window menu has the tab actions. -TabDemoTabs N opens N
   tabs at launch; -TabDemoEdited YES marks the second as edited.
*/

#import <AppKit/AppKit.h>
#import "GSWindowTabbing.h"

@interface TabDemoController : NSObject
{
  int _count;
}
- (NSWindow *) newDocumentWindow;
@end

@implementation TabDemoController

- (NSWindow *) newDocumentWindow
{
  NSWindow *window;
  NSScrollView *scroll;
  NSTextView *text;
  NSRect frame = NSMakeRect (200, 200, 640, 420);

  _count++;
  window = [[NSWindow alloc] initWithContentRect: frame
                                       styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                  | NSMiniaturizableWindowMask | NSResizableWindowMask
                                         backing: NSBackingStoreBuffered
                                           defer: NO];
  [window setTitle: [NSString stringWithFormat: @"Document %d.txt", _count]];
  [window setTabbingIdentifier: @"TabDemoDocument"];
  [window setReleasedWhenClosed: YES];
  scroll = [[NSScrollView alloc] initWithFrame: [[window contentView] bounds]];
  [scroll setHasVerticalScroller: YES];
  [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  text = [[NSTextView alloc] initWithFrame: [[scroll contentView] bounds]];
  [text setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [text setString: [NSString stringWithFormat:
    @"This is %@.\n\nCtrl+T or the + button opens a tab; Ctrl+Tab and "
    @"Ctrl+Page Down select the next one, Ctrl+Shift+Tab and Ctrl+Page Up "
    @"the previous one. The Window menu lists every tab.", [window title]]];
  [scroll setDocumentView: text];
  [window setContentView: scroll];
  RELEASE (text);
  RELEASE (scroll);
  return window;
}

/* The tab bar's "+" and File > New Tab: the new window is ordered in
   while the request is under way, and joins the asking window's
   group. */
- (IBAction) newWindowForTab: (id)sender
{
  NSWindow *window = [self newDocumentWindow];

  [window makeKeyAndOrderFront: nil];
}

/* A window of its own: no automatic joining. */
- (IBAction) newWindow: (id)sender
{
  NSWindow *window = [self newDocumentWindow];

  [window setTabbingMode: NSWindowTabbingModeDisallowed];
  [window makeKeyAndOrderFront: nil];
  [window setTabbingMode: NSWindowTabbingModeAutomatic];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSInteger tabs = [defaults integerForKey: @"TabDemoTabs"];
  NSWindow *first = [self newDocumentWindow];
  NSWindow *last = first;
  NSInteger i;

  [first makeKeyAndOrderFront: nil];
  for (i = 1; i < tabs; i++)
    {
      NSWindow *window = [self newDocumentWindow];

      /* NSWindowAbove puts the new tab right after the receiver's. */
      [last addTabbedWindow: window ordered: NSWindowAbove];
      last = window;
      if (i == 1 && [defaults boolForKey: @"TabDemoEdited"])
        {
          [window setDocumentEdited: YES];
        }
    }
  if (tabs > 1)
    {
      [[first tabGroup] setSelectedWindow: first];
    }
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)app
{
  return YES;
}

@end

static NSMenu *
TabDemoMenu (void)
{
  NSMenu *main = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"TabDemo"]);
  NSMenu *file = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"File"]);
  NSMenu *window = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"Window"]);
  NSMenuItem *item;

  [file addItemWithTitle: @"New Tab" action: @selector(newWindowForTab:) keyEquivalent: @"t"];
  [file addItemWithTitle: @"New Window" action: @selector(newWindow:) keyEquivalent: @"n"];
  [file addItemWithTitle: @"Close" action: @selector(performClose:) keyEquivalent: @"w"];
  [file addItemWithTitle: @"Quit" action: @selector(terminate:) keyEquivalent: @"q"];

  [window addItemWithTitle: @"Show Previous Tab" action: @selector(selectPreviousTab:) keyEquivalent: @""];
  [window addItemWithTitle: @"Show Next Tab" action: @selector(selectNextTab:) keyEquivalent: @""];
  [window addItemWithTitle: @"Move Tab to New Window" action: @selector(moveTabToNewWindow:) keyEquivalent: @""];
  [window addItemWithTitle: @"Merge All Windows" action: @selector(mergeAllWindows:) keyEquivalent: @""];
  [window addItemWithTitle: @"Show Tab Bar" action: @selector(toggleTabBar:) keyEquivalent: @""];

  item = (NSMenuItem *)[main addItemWithTitle: @"File" action: NULL keyEquivalent: @""];
  [main setSubmenu: file forItem: item];
  item = (NSMenuItem *)[main addItemWithTitle: @"Window" action: NULL keyEquivalent: @""];
  [main setSubmenu: window forItem: item];
  [NSApp setWindowsMenu: window];
  return main;
}

int
main (int argc, const char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  TabDemoController *controller;

  /* After NSApplication: GSTheme loads the user's theme. */
  [NSApplication sharedApplication];
  GSWindowTabbingInstall ();
  controller = [TabDemoController new];
  [NSApp setDelegate: controller];
  [NSApp setMainMenu: TabDemoMenu ()];
  [NSApp run];
  RELEASE (controller);
  [pool release];
  return 0;
}
