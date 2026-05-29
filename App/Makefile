TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iprox

iprox_FILES = main.m \
              IPAppDelegate.m \
              IPDeviceEntry.m \
              IPDeviceStore.m \
              IPScannerService.m \
              IPDeviceCell.m \
              IPDeviceListViewController.m \
              IPDeviceDetailViewController.m \
              IPSettingsViewController.m \
              ../Daemon/ContinuityDecoder.m \
              ../Daemon/ContinuityRecord.m \
              ../Daemon/Logger.m
iprox_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I$(THEOS_PROJECT_DIR)
iprox_FRAMEWORKS = UIKit Foundation CoreBluetooth CoreGraphics
iprox_LDFLAGS = -ldl

include $(THEOS_MAKE_PATH)/application.mk
