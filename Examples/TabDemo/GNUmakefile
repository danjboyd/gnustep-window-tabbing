# TabDemo: a group of tabbed document windows, through Apple's API only.
# It compiles the window tabbing code in, so it shows tabs under any
# theme (GNUstep's default drawing included).

include $(GNUSTEP_MAKEFILES)/common.make

GSWINDOWTABBING_DIR = ../..
include $(GSWINDOWTABBING_DIR)/GSWindowTabbing.make

APP_NAME = TabDemo
TabDemo_OBJC_FILES = main.m $(GSWINDOWTABBING_OBJC_FILES)
ADDITIONAL_INCLUDE_DIRS += $(GSWINDOWTABBING_INCLUDE_DIRS) -I$(GSWINDOWTABBING_DIR)/Source
ADDITIONAL_OBJCFLAGS += -Wall

include $(GNUSTEP_MAKEFILES)/application.make
