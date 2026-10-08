/* FakeWindow.h: a stand-in window for the model's tests: it records
   what the tab group asks of it, with no display.

   Copyright (C) 2026 Daniel Boyd

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
*/

#import <Foundation/Foundation.h>
#import "GSWindowTabbingPrivate.h"

@interface FakeWindow : NSObject <GSWindowTabbable>
{
@public
  NSString *name;
  NSString *filename;
  NSRect frame;
  BOOL visible;
  BOOL maximized;
  BOOL key;
  BOOL edited;
  NSString *identifier;
  NSWindowTabGroup *group;
  int changes;
}
+ (FakeWindow *) named: (NSString *)name;
- (BOOL) isVisible;
@end

@implementation FakeWindow
+ (FakeWindow *) named: (NSString *)aName
{
  FakeWindow *w = AUTORELEASE ([FakeWindow new]);

  w->name = RETAIN (aName);
  w->frame = NSMakeRect (10, 10, 300, 200);
  w->visible = YES;
  w->identifier = @"doc";
  return w;
}
- (void) dealloc
{
  RELEASE (name);
  RELEASE (filename);
  RELEASE (group);
  [super dealloc];
}
- (NSString *) description { return name; }
- (NSRect) frame { return frame; }
- (NSString *) title { return name; }
- (NSString *) representedFilename { return filename; }
- (BOOL) isKeyWindow { return key; }
- (BOOL) isDocumentEdited { return edited; }
- (BOOL) isVisible { return visible; }
- (NSWindowTabbingIdentifier) tabbingIdentifier { return identifier; }
- (BOOL) _tabbingIsMaximized { return maximized; }
- (void) _tabbingShowWithFrame: (NSRect)f
                     maximized: (BOOL)m
                       makeKey: (BOOL)makeKey
{
  frame = f;
  maximized = m;
  visible = YES;
  key = makeKey;
}
- (void) _tabbingHide
{
  visible = NO;
  key = NO;
}
- (void) _tabbingGroupDidChange { changes++; }
- (NSWindowTabGroup *) _tabbingGroup { return group; }
- (void) _setTabbingGroup: (NSWindowTabGroup *)g { ASSIGN (group, g); }
@end
