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
#import "../../../Source/NSWindowTabGroup.m"
#import "../../../Source/NSWindowTab.m"
#import "../../../Source/GSWindowTabBarLayout.m"

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
      PASS ([b _tabbingGroup] == group, "the window knows its group");

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
      [group _selectNextTab: YES];
      PASS ([[[group selectedWindow] description] isEqual: @"B"], "next tab");
      [group _selectNextTab: NO];
      [group _selectNextTab: NO];
      PASS ([[[group selectedWindow] description] isEqual: @"D"], "previous tab wraps round");
      [group _selectNextTab: YES];
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
      [group _windowWillLeave: b];
      PASS ([group selectedWindow] == (id)c && c->visible,
            "closing the selected tab selects its right-hand neighbour");
      PASS (NSEqualRects (c->frame, NSMakeRect (70, 70, 330, 230)) && c->key,
            "which takes its place, frame and key status");
      [group _windowWillLeave: c];
      PASS ([group selectedWindow] == (id)a && a->visible,
            "closing the last tab selects the one before it");
      PASS ([group isTabBarVisible] == NO, "back to one window: the bar hides");
      [group _windowWillLeave: a];
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
      [group _windowWillLeave: a];
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
      PASS ([c _tabbingGroup] == one && [[one windows] count] == 2,
            "a window added to another group joins it");
      PASS ([[two windows] count] == 1 && [two selectedWindow] == (id)b && b->visible,
            "and leaves its old group, whose other window shows again");

      [one removeWindow: (NSWindow *)c];
      PASS ([c _tabbingGroup] == nil && [[one windows] count] == 1,
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
      [group _windowWillLeave: b];
      [inner release];
      PASS ([a retainCount] == aCount, "and lets go when one is left");
      [a _setTabbingGroup: nil];
      [b _setTabbingGroup: nil];
      RELEASE (group);
      RELEASE (a);
      RELEASE (b);
    }
  END_SET ("retention")

  START_SET ("the tab bar's visibility")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      NSWindowTabGroup *group = groupWith (a);

      [group _toggleTabBar];
      PASS ([group isTabBarVisible], "toggling shows the bar for one window");
      [group addWindow: (NSWindow *)[FakeWindow named: @"B"]];
      [group _toggleTabBar];
      PASS ([group isTabBarVisible] == NO, "and hides it again, even with two");
      [group _toggleTabBar];
      PASS ([group isTabBarVisible], "shown again");
      [group _windowWillLeave: [[group windows] lastObject]];
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
      ASSIGN (a->name, @"Report.md  --  /home/me/Notes");
      ASSIGN (a->filename, @"/home/me/Notes/Report.md");
      PASS_EQUAL ([tab title], @"Report.md",
                  "a window showing a file: its file name, not GNUstep's title with the folder");
      ASSIGN (a->name, @"Draft");
      PASS_EQUAL ([tab title], @"Draft",
                  "a title the app set after the file: the window's title");
      ASSIGN (a->name, @"Window");
      ASSIGN (a->filename, @"Window");
      PASS_EQUAL ([tab title], @"Window",
                  "GNUstep's default represented filename (\"Window\"): the title");
      ASSIGN (a->filename, @"");
      ASSIGN (a->name, @"Report.md  --  /home/me/Notes");
      PASS_EQUAL ([tab title], @"Report.md  --  /home/me/Notes",
                  "an empty represented filename: the window's title");
      ASSIGN (a->name, @"Renamed.md");
      [tab setTitle: @"Custom"];
      ASSIGN (a->filename, @"/home/me/Notes/Report.md");
      PASS_EQUAL ([tab title], @"Custom",
                  "unless the tab has one of its own, even for a file");
      DESTROY (a->filename);
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

  START_SET ("reordering and dropping (what a dragged tab does)")
    {
      FakeWindow *a = [FakeWindow named: @"A"];
      FakeWindow *b = [FakeWindow named: @"B"];
      FakeWindow *c = [FakeWindow named: @"C"];
      FakeWindow *d = [FakeWindow named: @"D"];
      NSWindowTabGroup *one = groupWith (a);
      NSWindowTabGroup *two = groupWith (d);

      [one addWindow: (NSWindow *)b];
      [one addWindow: (NSWindow *)c];
      [one setSelectedWindow: (NSWindow *)a];
      [one insertWindow: (NSWindow *)a atIndex: 2];
      PASS_EQUAL (names ([one windows]), ([NSArray arrayWithObjects: @"B", @"C", @"A", nil]),
                  "a tab dragged to the last slot moves there");
      PASS ([one selectedWindow] == (id)a && a->visible && b->visible == NO,
            "and stays the selected one, still on screen");
      [one insertWindow: (NSWindow *)a atIndex: 0];
      PASS_EQUAL (names ([one windows]), ([NSArray arrayWithObjects: @"A", @"B", @"C", nil]),
                  "and back to the first");
      [two insertWindow: (NSWindow *)a atIndex: 0];
      PASS_EQUAL (names ([two windows]), ([NSArray arrayWithObjects: @"A", @"D", nil]),
                  "a tab dropped on another group's bar lands in the slot it was dropped in");
      PASS ([two selectedWindow] == (id)a && a->visible && d->visible == NO,
            "and is that group's selected tab");
      PASS_EQUAL (names ([one windows]), ([NSArray arrayWithObjects: @"B", @"C", nil]),
                  "leaving its old group");
      PASS (([one selectedWindow] == (id)b && b->visible) || ([one selectedWindow] == (id)c && c->visible),
            "whose neighbour tab is shown in its place");
    }
  END_SET ("reordering and dropping (what a dragged tab does)")

  START_SET ("slots while a tab is dragged")
    {
      /* Four tabs; tab 1 dragged to slot 3: the others close up behind
         it and open a gap at 3. */
      PASS (GSWindowTabSlot (0, 1, 3, NO) == 0, "a tab before both stays");
      PASS (GSWindowTabSlot (2, 1, 3, NO) == 1, "a tab after the dragged one closes up");
      PASS (GSWindowTabSlot (3, 1, 3, NO) == 2, "up to the gap");
      PASS (GSWindowTabSlot (1, 1, 3, NO) == 3, "the dragged tab is in its slot");
      PASS (GSWindowTabSlot (3, 1, 0, NO) == 3, "dragged to the start, the others move right");
      PASS (GSWindowTabSlot (0, 1, 0, NO) == 1, "even the first");
      PASS (GSWindowTabSlot (3, 1, 3, YES) == 2, "pulled out of the bar: no gap");
      PASS (GSWindowTabSlotAtOffset (0, 100, 6, 4) == 0, "the slot nearest a left edge: the first");
      PASS (GSWindowTabSlotAtOffset (160, 100, 6, 4) == 2, "past half a step: the next slot");
      PASS (GSWindowTabSlotAtOffset (900, 100, 6, 4) == 3, "never past the last");
      PASS (GSWindowTabSlotAtOffset (-50, 100, 6, 4) == 0, "nor before the first");
    }
  END_SET ("slots while a tab is dragged")

  START_SET ("scrolling to show a tab")
    {
      /* Tabs 100 wide in a 250 wide area, scrollable by up to 400. */
      PASS (GSWindowTabScrollToShow (0, 100, 100, 250, 400) == 0, "a tab in sight: no scrolling");
      PASS (GSWindowTabScrollToShow (0, 300, 100, 250, 400) == 150, "one to the right: just into sight");
      PASS (GSWindowTabScrollToShow (300, 100, 100, 250, 400) == 100, "one to the left: just into sight");
      PASS (GSWindowTabScrollToShow (0, 600, 100, 250, 400) == 400, "never past the end");
    }
  END_SET ("scrolling to show a tab")

  [pool release];
  return 0;
}
