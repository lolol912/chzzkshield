TARGET := iphone:clang:latest:11.0
INSTALL_TARGET_PROCESSES = CHZZK NaverGameApp

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CHZZKShield

CHZZKShield_FILES = Tweak.x
CHZZKShield_CFLAGS = -fobjc-arc
CHZZKShield_FRAMEWORKS = Foundation AVFoundation WebKit

include $(THEOS_MAKE_PATH)/tweak.mk
