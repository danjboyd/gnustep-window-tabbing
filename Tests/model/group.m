/* group.m: NSWindowTabGroup and NSWindowTab, with stand-in windows (no
   display): membership, selection and the frame it carries, ordering,
   leaving (closing), retention, the tab bar's visibility, titles.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
*/

#import "Testing.h"
#import "FakeWindow.h"
/* The model itself, compiled into the test: it needs no NSWindow. */
#import "../../Source/GSWindowTabGroup.m"

static NSArray *
names (NSArray *windows)
{
  NSMutableArray *a = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [windows count]; i++)
    {
      [a addObject: [[windows objectAtIndex: i] description]];
    }
  return a;
}

static NSWindowTabGroup *
groupWith (FakeWindow *first)
{
  NSWindowTabGroup *group = AUTORELEASE ([[NSWindowTabGroup alloc]
                                           initWithIdentifier: @"doc"]);

  [group addWindow: (NSWindow *)first];
  return group;
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  START_SET ("membership and selection")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      FakeWindow *b = [FakeWindow named: @"B"];
      NSWindowTabGroup *group = groupWith (a);

      a->key = YES;
      PASS ([[group windows] count] == 1 && [group selectedWindow] == (id)a,
            "a group made for a window has it, selected");
      PASS ([group isTabBarVisible] == NO, "one window: no tab bar");

      b->frame = NSMakeRect (500, 500, 100, 100);
      [group addWindow: (NSWindow *)b];
      PASS_EQUAL (names ([group windows]), ([NSArray arrayWithObjects: @"A", @"B", nil]),
                  "an added window goes at the end");
      PASS ([group selectedWindow] == (id)b, "an added window becomes the selected tab");
      PASS (a->visible == NO && b->visible == YES, "only the selected window is on screen");
      PASS (NSEqualRects (b->frame, NSMakeRect (10, 10, 300, 200)),
            "the new selected window takes the old one's frame");
      PASS (b->key == YES && a->key == NO, "and its key status");
      PASS ([group isTabBarVisible], "two windows: the tab bar shows");
      PASS ([b gsTabGroup] == group, "the window knows its group");

      b->frame = NSMakeRect (40, 40, 320, 220);
      [group setSelectedWindow: (NSWindow *)a];
      PASS ([group selectedWindow] == (id)a && a->visible && b->visible == NO,
            "selecting a tab shows it and hides the other");
      PASS (NSEqualRects (a->frame, NSMakeRect (40, 40, 320, 220)),
            "with the frame the group had (moves and resizes act on the group)");
      [group setSelectedWindow: (NSWindow *)[FakeWindow named: @"X"]];
      PASS ([group selectedWindow] == (id)a, "a window not in the group can't be selected");
    }
  END_SET ("membership and selection")

  START_SET ("ordering")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      FakeWindow *b = [FakeWindow named: @"B"];
      FakeWindow *c = [FakeWindow named: @"C"];
      NSWindowTabGroup *group = groupWith (a);

      [group addWindow: (NSWindow *)b];
      [group insertWindow: (NSWindow *)c atIndex: 0];
      PASS_EQUAL (names ([group windows]), ([NSArray arrayWithObjects: @"C", @"A", @"B", nil]),
                  "insertWindow:atIndex: puts it there");
      [group insertWindow: (NSWindow *)c atIndex: 2];
      PASS_EQUAL (names ([group windows]), ([NSArray arrayWithObjects: @"A", @"B", @"C", nil]),
                  "inserting a member again moves it");
      [group insertWindow: (NSWindow *)[FakeWindow named: @"D"] atIndex: 99];
      PASS ([[group windows] count] == 4 && [[[[group windows] lastObject] description] isEqual: @"D"],
            "an index past the end appends");

      [group setSelectedWindow: (NSWindow *)a];
      [group gsSelectNextTab: YES];
      PASS ([[[group selectedWindow] description] isEqual: @"B"], "next tab");
      [group gsSelectNextTab: NO];
      [group gsSelectNextTab: NO];
      PASS ([[[group selectedWindow] description] isEqual: @"D"], "previous tab wraps round");
      [group gsSelectNextTab: YES];
      PASS ([[[group selectedWindow] description] isEqual: @"A"], "next tab wraps round");
    }
  END_SET ("ordering")

  START_SET ("leaving and closing")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      FakeWindow *b = [FakeWindow named: @"B"];
      FakeWindow *c = [FakeWindow named: @"C"];
      NSWindowTabGroup *group = groupWith (a);

      [group addWindow: (NSWindow *)b];
      [group addWindow: (NSWindow *)c];
      [group setSelectedWindow: (NSWindow *)b];
      b->key = YES;
      b->frame = NSMakeRect (70, 70, 330, 230);
      [group gsWindowWillLeave: b];
      PASS ([group selectedWindow] == (id)c && c->visible,
            "closing the selected tab selects its right-hand neighbour");
      PASS (NSEqualRects (c->frame, NSMakeRect (70, 70, 330, 230)) && c->key,
            "which takes its place, frame and key status");
      [group gsWindowWillLeave: c];
      PASS ([group selectedWindow] == (id)a && a->visible,
            "closing the last tab selects the one before it");
      PASS ([group isTabBarVisible] == NO, "back to one window: the bar hides");
      [group gsWindowWillLeave: a];
      PASS ([[group windows] count] == 0 && [group selectedWindow] == nil,
            "closing the last window empties the group");
    }
  END_SET ("leaving and closing")

  START_SET ("leaving a hidden tab")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      FakeWindow *b = [FakeWindow named: @"B"];
      NSWindowTabGroup *group = groupWith (a);

      [group addWindow: (NSWindow *)b];
      [group gsWindowWillLeave: a];
      PASS ([group selectedWindow] == (id)b && b->visible && a->visible == NO,
            "closing a hidden tab leaves the selection alone");
    }
  END_SET ("leaving a hidden tab")

  START_SET ("moving between groups")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      FakeWindow *b = [FakeWindow named: @"B"];
      FakeWindow *c = [FakeWindow named: @"C"];
      NSWindowTabGroup *one = groupWith (a);
      NSWindowTabGroup *two = groupWith (b);

      [two addWindow: (NSWindow *)c];
      [one addWindow: (NSWindow *)c];
      PASS ([c gsTabGroup] == one && [[one windows] count] == 2,
            "a window added to another group joins it");
      PASS ([[two windows] count] == 1 && [two selectedWindow] == (id)b && b->visible,
            "and leaves its old group, whose other window shows again");

      [one removeWindow: (NSWindow *)c];
      PASS ([c gsTabGroup] == nil && [[one windows] count] == 1,
            "removeWindow: takes a window out of its group");
    }
  END_SET ("moving between groups")

  START_SET ("retention")
    {
      FakeWindow *a = [FakeWindow new];
      FakeWindow *b = [FakeWindow new];
      NSWindowTabGroup *group = [[NSWindowTabGroup alloc] initWithIdentifier: @"doc"];
      NSAutoreleasePool *inner;
      NSUInteger aCount;

      a->frame = b->frame = NSMakeRect (0, 0, 10, 10);
      aCount = [a retainCount];
      /* Each step in a pool of its own: -windows hands out autoreleased
         arrays, which hold the windows until their pool goes. */
      inner = [NSAutoreleasePool new];
      [group addWindow: (NSWindow *)a];
      [inner release];
      PASS ([a retainCount] == aCount, "a group doesn't retain a window on its own");
      inner = [NSAutoreleasePool new];
      [group addWindow: (NSWindow *)b];
      [inner release];
      PASS ([a retainCount] == aCount + 1, "with two windows it retains them (hidden tabs)");
      inner = [NSAutoreleasePool new];
      [group gsWindowWillLeave: b];
      [inner release];
      PASS ([a retainCount] == aCount, "and lets go when one is left");
      [a gsSetTabGroup: nil];
      [b gsSetTabGroup: nil];
      RELEASE (group);
      RELEASE (a);
      RELEASE (b);
    }
  END_SET ("retention")

  START_SET ("the tab bar's visibility")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      NSWindowTabGroup *group = groupWith (a);

      [group gsToggleTabBar];
      PASS ([group isTabBarVisible], "toggling shows the bar for one window");
      [group addWindow: (NSWindow *)[FakeWindow named: @"B"]];
      [group gsToggleTabBar];
      PASS ([group isTabBarVisible] == NO, "and hides it again, even with two");
      [group gsToggleTabBar];
      PASS ([group isTabBarVisible], "shown again");
      [group gsWindowWillLeave: [[group windows] lastObject]];
      PASS ([group isTabBarVisible] == NO,
            "hidden and shown again with two tabs is automatic: it goes at one");
      PASS (a->changes > 0, "windows hear of every change (to redraw the bar)");
    }
  END_SET ("the tab bar's visibility")

  START_SET ("tab titles")
    {
      FakeWindow *a = [FakeWindow named: @"Report.md"];
      NSWindowTab *tab = AUTORELEASE ([[NSWindowTab alloc] initWithWindow: (NSWindow *)a]);

      PASS_EQUAL ([tab title], @"Report.md", "a tab's title is its window's");
      ASSIGN (a->name, @"Renamed.md");
      PASS_EQUAL ([tab title], @"Renamed.md", "and follows it");
      [tab setTitle: @"Custom"];
      PASS_EQUAL ([tab title], @"Custom", "unless the tab has one of its own");
      [tab setTitle: nil];
      [tab setAttributedTitle: AUTORELEASE ([[NSAttributedString alloc] initWithString: @"Styled"])];
      PASS_EQUAL ([tab title], @"Styled", "or an attributed one");
    }
  END_SET ("tab titles")

  START_SET ("tab widths")
    {
      PASS (GSWindowTabWidth (2, 1000, 80, 240) == 240, "wide bar: tabs at their maximum");
      PASS (GSWindowTabWidth (4, 600, 80, 240) == 150, "tabs share the bar equally");
      PASS (GSWindowTabWidth (10, 600, 80, 240) == 80, "never below the minimum");
      PASS (GSWindowTabWidth (0, 600, 80, 240) == 0, "no tabs, no width");
    }
  END_SET ("tab widths")

  [pool release];
  return 0;
}
