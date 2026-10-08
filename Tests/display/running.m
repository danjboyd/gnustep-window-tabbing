/* running.m: tabbing in a running app. The tab shortcuts reach the
   group while a text view that takes Ctrl key equivalents has focus, and
   closing the selected tab doesn't count as closing the last window (so
   an app whose delegate says to terminate after the last window doesn't
   quit). Needs a display (a private Xvfb, no window manager needed);
   skips without one.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
*/

#import "Testing.h"
#import <AppKit/AppKit.h>
#import "GSWindowTabbing.h"

/* A text view that takes Ctrl+Tab and Ctrl+Page Down as key
   equivalents, as editors with their own key bindings do: before the
   fix, the window offered them to it first. */
@interface GreedyTextView : NSTextView
{
@public
  int taken;
}
@end

@implementation GreedyTextView
- (BOOL) performKeyEquivalent: (NSEvent *)event
{
  if ([event modifierFlags] & (NSControlKeyMask | NSCommandKeyMask))
    {
      taken++;
      return YES;
    }
  return [super performKeyEquivalent: event];
}
@end

@interface Delegate : NSObject
{
@public
  int lastWindowAsks;
  int terminateAsks;
  NSWindow *a, *b;
  GreedyTextView *textA, *textB;
}
@end

static NSWindow *
makeWindow (NSString *title, GreedyTextView **text)
{
  NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect (100, 100, 400, 300)
                                            styleMask: NSTitledWindowMask | NSClosableWindowMask
                                                       | NSResizableWindowMask
                                              backing: NSBackingStoreBuffered
                                                defer: NO];
  *text = [[GreedyTextView alloc] initWithFrame: NSMakeRect (0, 0, 400, 250)];
  [w setTitle: title];
  [w setTabbingIdentifier: @"doc"];
  [w setTabbingMode: NSWindowTabbingModePreferred];
  [w setReleasedWhenClosed: NO];
  [[w contentView] addSubview: *text];
  return w;
}

/* Ctrl with c, the Ctrl key arriving as mask: NSControlKeyMask, or
   NSCommandKeyMask as GNUstep's default key mapping delivers it. */
static NSEvent *
ctrlKey (NSWindow *window, unichar c, NSUInteger mask)
{
  NSString *s = [NSString stringWithCharacters: &c length: 1];

  return [NSEvent keyEventWithType: NSKeyDown location: NSZeroPoint
                     modifierFlags: mask timestamp: 0
                      windowNumber: [window windowNumber] context: nil
                        characters: s charactersIgnoringModifiers: s
                         isARepeat: NO keyCode: 0];
}

@implementation Delegate

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)app
{
  lastWindowAsks++;
  return YES;
}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)app
{
  terminateAsks++;
  return NSTerminateCancel;
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  a = makeWindow (@"A", &textA);
  b = makeWindow (@"B", &textB);
  [a makeKeyAndOrderFront: nil];
  [self performSelector: @selector(step1) withObject: nil afterDelay: 0.3];
}

- (void) step1
{
  [b makeKeyAndOrderFront: nil];
  [self performSelector: @selector(step2) withObject: nil afterDelay: 0.3];
}

- (void) step2
{
  PASS ([[a tabbedWindows] count] == 2 && [[a tabGroup] selectedWindow] == b,
        "two windows in one group, the second selected");
  [b makeKeyWindow];
  [b makeFirstResponder: textB];
  [self performSelector: @selector(step3) withObject: nil afterDelay: 0.3];
}

- (void) step3
{
  PASS ([NSApp keyWindow] == b && [b firstResponder] == textB,
        "the selected tab is key, its text view has focus");
  [NSApp sendEvent: ctrlKey (b, '\t', NSControlKeyMask)];
  PASS ([[a tabGroup] selectedWindow] == a && textB->taken == 0,
        "Ctrl+Tab selects the next tab, ahead of the focused text view");
  [a makeKeyWindow];
  [a makeFirstResponder: textA];
  [self performSelector: @selector(step4) withObject: nil afterDelay: 0.3];
}

- (void) step4
{
  [NSApp sendEvent: ctrlKey (a, NSPageDownFunctionKey, NSCommandKeyMask)];
  PASS ([[a tabGroup] selectedWindow] == b && textA->taken == 0,
        "and Ctrl+Page Down, with Ctrl as GNUstep's default mapping delivers it (Command)");
  [self performSelector: @selector(step5) withObject: nil afterDelay: 0.3];
}

- (void) step5
{
  /* b is the selected tab, the only window on screen. */
  [b performClose: nil];
  [self performSelector: @selector(step6) withObject: nil afterDelay: 0.6];
}

- (void) step6
{
  PASS ([a isVisible] && [a tabbedWindows] == nil,
        "closing the selected tab shows the other one");
  PASS (lastWindowAsks == 0 && terminateAsks == 0,
        "and the app isn't told its last window closed");
  /* The check works: closing a window on its own is the last one. */
  [a performClose: nil];
  [self performSelector: @selector(step7) withObject: nil afterDelay: 0.6];
}

- (void) step7
{
  PASS (lastWindowAsks == 1,
        "closing the last window does ask (the check above can fail)");
  [NSApp stop: nil];
  [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined
                                       location: NSZeroPoint modifierFlags: 0
                                      timestamp: 0 windowNumber: 0 context: nil
                                        subtype: 0 data1: 0 data2: 0]
           atStart: NO];
}

@end

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("tabbing in a running app")
    {
      Delegate *delegate;

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
      delegate = [Delegate new];
      [NSApp setDelegate: (id)delegate];
      [NSApp run];
    }
  END_SET ("tabbing in a running app")

  [pool release];
  return 0;
}
