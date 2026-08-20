ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = LCMemEditor

LCMemEditor_FILES = $(wildcard Sources/*.m)
LCMemEditor_CFLAGS = -fobjc-arc -Wall -ISources
LCMemEditor_FRAMEWORKS = UIKit Foundation
LCMemEditor_LIBRARY_EXTENSION = .dylib
LCMemEditor_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
