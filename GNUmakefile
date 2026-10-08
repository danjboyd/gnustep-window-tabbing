# Builds the window tabbing code as a library, the demo, and runs the
# tests. Themes don't use this: they compile the sources in through
# GSWindowTabbing.make.

include $(GNUSTEP_MAKEFILES)/common.make

GSWINDOWTABBING_DIR = .
include GSWindowTabbing.make

LIBRARY_NAME = libGSWindowTabbing
libGSWindowTabbing_OBJC_FILES = $(GSWINDOWTABBING_OBJC_FILES)
libGSWindowTabbing_HEADER_FILES_DIR = Headers
libGSWindowTabbing_HEADER_FILES = GSWindowTabbing.h \
  AppKit/NSWindowTab.h AppKit/NSWindowTabGroup.h
libGSWindowTabbing_LIBRARIES_DEPEND_UPON = -lgnustep-gui $(FND_LIBS) $(OBJC_LIBS)
ADDITIONAL_INCLUDE_DIRS += $(GSWINDOWTABBING_INCLUDE_DIRS)
ADDITIONAL_OBJCFLAGS += -Wall

SUBPROJECTS =
include $(GNUSTEP_MAKEFILES)/library.make

tabdemo: all
	$(MAKE) -C Examples/TabDemo

# The model, with no display.
check-model: all
	cd Tests && gnustep-tests model

# The NSWindow glue: needs a display (a private Xvfb; DISPLAY must be set,
# and no window manager is needed). Runs with empty user defaults.
check-display: all
	cd Tests && LD_LIBRARY_PATH=$(CURDIR)/obj:$$LD_LIBRARY_PATH gnustep-tests display
