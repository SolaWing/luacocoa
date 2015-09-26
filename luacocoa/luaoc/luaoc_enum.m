//
//  luaoc_enum.m
//  luaoc
//
//  Created by SolaWing on 15/9/26.
//  Copyright © 2015年 sw. All rights reserved.
//

#import "luaoc_enum.h"
#import "lauxlib.h"

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreData/CoreData.h>

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    #import <UIKit/UIKit.h>
#else
#endif

/** top is a table, use to hold the enum value */
static void reg_def_enum(lua_State *L) {

#define REG_ENUM(Enum)                      \
    lua_pushstring(L, #Enum);               \
    lua_pushinteger(L, Enum);               \
    lua_rawset(L, -3);                      \

    // NSOperationQueuePriority
    REG_ENUM(NSOperationQueuePriorityVeryLow);
    REG_ENUM(NSOperationQueuePriorityLow);
    REG_ENUM(NSOperationQueuePriorityNormal);
    REG_ENUM(NSOperationQueuePriorityHigh);
    REG_ENUM(NSOperationQueuePriorityVeryHigh);

    // NSFetchRequestResultType
    REG_ENUM(NSManagedObjectResultType);
    REG_ENUM(NSManagedObjectIDResultType);
    REG_ENUM(NSDictionaryResultType);
    REG_ENUM(NSCountResultType);
    // NSManagedObjectContextConcurrencyType
    REG_ENUM(NSConfinementConcurrencyType);
    REG_ENUM(NSPrivateQueueConcurrencyType);
    REG_ENUM(NSMainQueueConcurrencyType);
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    // UIControlEvents
    REG_ENUM(UIControlEventTouchDown);
    REG_ENUM(UIControlEventTouchDownRepeat);
    REG_ENUM(UIControlEventTouchDragInside);
    REG_ENUM(UIControlEventTouchDragOutside);
    REG_ENUM(UIControlEventTouchDragEnter);
    REG_ENUM(UIControlEventTouchDragExit);
    REG_ENUM(UIControlEventTouchUpInside);
    REG_ENUM(UIControlEventTouchUpOutside);
    REG_ENUM(UIControlEventTouchCancel);
    REG_ENUM(UIControlEventValueChanged);
    REG_ENUM(UIControlEventPrimaryActionTriggered);

    REG_ENUM(UIControlEventEditingDidBegin);
    REG_ENUM(UIControlEventEditingChanged);
    REG_ENUM(UIControlEventEditingDidEnd);
    REG_ENUM(UIControlEventEditingDidEndOnExit);

    REG_ENUM(UIControlEventAllTouchEvents);
    REG_ENUM(UIControlEventAllEditingEvents);
    REG_ENUM(UIControlEventApplicationReserved);
    REG_ENUM(UIControlEventSystemReserved);
    REG_ENUM(UIControlEventAllEvents);


    // UIControlState
    REG_ENUM(UIControlStateNormal);
    REG_ENUM(UIControlStateHighlighted);
    REG_ENUM(UIControlStateDisabled);
    REG_ENUM(UIControlStateSelected);
    REG_ENUM(UIControlStateApplication);
    REG_ENUM(UIControlStateReserved);
    REG_ENUM(UIViewAnimationOptionLayoutSubviews);
    REG_ENUM(UIViewAnimationOptionAllowUserInteraction);
    REG_ENUM(UIViewAnimationOptionBeginFromCurrentState);
    REG_ENUM(UIViewAnimationOptionRepeat);
    REG_ENUM(UIViewAnimationOptionAutoreverse);
    REG_ENUM(UIViewAnimationOptionOverrideInheritedDuration);
    REG_ENUM(UIViewAnimationOptionOverrideInheritedCurve);
    REG_ENUM(UIViewAnimationOptionAllowAnimatedContent);
    REG_ENUM(UIViewAnimationOptionShowHideTransitionViews);
    REG_ENUM(UIViewAnimationOptionOverrideInheritedOptions);

    REG_ENUM(UIViewAnimationOptionCurveEaseInOut);
    REG_ENUM(UIViewAnimationOptionCurveEaseIn);
    REG_ENUM(UIViewAnimationOptionCurveEaseOut);
    REG_ENUM(UIViewAnimationOptionCurveLinear);

    REG_ENUM(UIViewAnimationOptionTransitionNone);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromLeft);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromRight);
    REG_ENUM(UIViewAnimationOptionTransitionCurlUp);
    REG_ENUM(UIViewAnimationOptionTransitionCurlDown);
    REG_ENUM(UIViewAnimationOptionTransitionCrossDissolve);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromTop);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromBottom);
    // UIInterfaceOrientationMask
    REG_ENUM(UIInterfaceOrientationMaskPortrait);
    REG_ENUM(UIInterfaceOrientationMaskLandscapeLeft);
    REG_ENUM(UIInterfaceOrientationMaskLandscapeRight);
    REG_ENUM(UIInterfaceOrientationMaskPortraitUpsideDown);
    REG_ENUM(UIInterfaceOrientationMaskLandscape);
    REG_ENUM(UIInterfaceOrientationMaskAll);
    REG_ENUM(UIInterfaceOrientationMaskAllButUpsideDown);

    // NSLayoutRelation
    REG_ENUM(NSLayoutRelationLessThanOrEqual);
    REG_ENUM(NSLayoutRelationEqual);
    REG_ENUM(NSLayoutRelationGreaterThanOrEqual);

    // NSLineBreakMode
    REG_ENUM(NSLineBreakByWordWrapping);
    REG_ENUM(NSLineBreakByCharWrapping);
    REG_ENUM(NSLineBreakByClipping);
    REG_ENUM(NSLineBreakByTruncatingHead);
    REG_ENUM(NSLineBreakByTruncatingTail);
    REG_ENUM(NSLineBreakByTruncatingMiddle);

    // UIModalTransitionStyle
    REG_ENUM(UIModalTransitionStyleCoverVertical);
    REG_ENUM(UIModalTransitionStyleFlipHorizontal);
    REG_ENUM(UIModalTransitionStyleCrossDissolve);
    REG_ENUM(UIModalTransitionStylePartialCurl);


    // UIModalPresentationStyle
    REG_ENUM(UIModalPresentationFullScreen);
    REG_ENUM(UIModalPresentationPageSheet);
    REG_ENUM(UIModalPresentationFormSheet);
    REG_ENUM(UIModalPresentationCurrentContext);
    REG_ENUM(UIModalPresentationCustom);
    REG_ENUM(UIModalPresentationOverFullScreen);
    REG_ENUM(UIModalPresentationOverCurrentContext);
    REG_ENUM(UIModalPresentationPopover);
    REG_ENUM(UIModalPresentationNone);

    // NSTextAlignment
    REG_ENUM(NSTextAlignmentLeft);
    REG_ENUM(NSTextAlignmentCenter);
    REG_ENUM(NSTextAlignmentRight);
    REG_ENUM(NSTextAlignmentJustified);
    REG_ENUM(NSTextAlignmentNatural);


    // NSWritingDirection
    REG_ENUM(NSWritingDirectionNatural);
    REG_ENUM(NSWritingDirectionLeftToRight);
    REG_ENUM(NSWritingDirectionRightToLeft);


    // UIActivityIndicatorViewStyle
    REG_ENUM(UIActivityIndicatorViewStyleWhiteLarge);
    REG_ENUM(UIActivityIndicatorViewStyleWhite);
    REG_ENUM(UIActivityIndicatorViewStyleGray);

    // UIViewAnimationCurve
    REG_ENUM(UIViewAnimationCurveEaseInOut);
    REG_ENUM(UIViewAnimationCurveEaseIn);
    REG_ENUM(UIViewAnimationCurveEaseOut);
    REG_ENUM(UIViewAnimationCurveLinear);


    // UIViewContentMode
    REG_ENUM(UIViewContentModeScaleToFill);
    REG_ENUM(UIViewContentModeScaleAspectFit);
    REG_ENUM(UIViewContentModeScaleAspectFill);
    REG_ENUM(UIViewContentModeRedraw);
    REG_ENUM(UIViewContentModeCenter);
    REG_ENUM(UIViewContentModeTop);
    REG_ENUM(UIViewContentModeBottom);
    REG_ENUM(UIViewContentModeLeft);
    REG_ENUM(UIViewContentModeRight);
    REG_ENUM(UIViewContentModeTopLeft);
    REG_ENUM(UIViewContentModeTopRight);
    REG_ENUM(UIViewContentModeBottomLeft);
    REG_ENUM(UIViewContentModeBottomRight);


    // UIViewAnimationTransition
    REG_ENUM(UIViewAnimationTransitionNone);
    REG_ENUM(UIViewAnimationTransitionFlipFromLeft);
    REG_ENUM(UIViewAnimationTransitionFlipFromRight);
    REG_ENUM(UIViewAnimationTransitionCurlUp);
    REG_ENUM(UIViewAnimationTransitionCurlDown);


    // UIViewTintAdjustmentMode
    REG_ENUM(UIViewTintAdjustmentModeAutomatic);

    REG_ENUM(UIViewTintAdjustmentModeNormal);
    REG_ENUM(UIViewTintAdjustmentModeDimmed);
    // UITouchPhase
    REG_ENUM(UITouchPhaseBegan);
    REG_ENUM(UITouchPhaseMoved);
    REG_ENUM(UITouchPhaseStationary);
    REG_ENUM(UITouchPhaseEnded);
    REG_ENUM(UITouchPhaseCancelled);


    // UIForceTouchCapability
    REG_ENUM(UIForceTouchCapabilityUnknown);
    REG_ENUM(UIForceTouchCapabilityUnavailable);
    REG_ENUM(UIForceTouchCapabilityAvailable);

    // UITextBorderStyle
    REG_ENUM(UITextBorderStyleNone);
    REG_ENUM(UITextBorderStyleLine);
    REG_ENUM(UITextBorderStyleBezel);
    REG_ENUM(UITextBorderStyleRoundedRect);
    // UITableViewRowAnimation
    REG_ENUM(UITableViewRowAnimationFade);
    REG_ENUM(UITableViewRowAnimationRight);
    REG_ENUM(UITableViewRowAnimationLeft);
    REG_ENUM(UITableViewRowAnimationTop);
    REG_ENUM(UITableViewRowAnimationBottom);
    REG_ENUM(UITableViewRowAnimationNone);
    REG_ENUM(UITableViewRowAnimationMiddle);
    REG_ENUM(UITableViewRowAnimationAutomatic);
    // UISegmentedControlStyle
    REG_ENUM(UISegmentedControlStylePlain);
    REG_ENUM(UISegmentedControlStyleBordered);
    REG_ENUM(UISegmentedControlStyleBar);
    REG_ENUM(UISegmentedControlStyleBezeled);


    // UISegmentedControlSegment
    REG_ENUM(UISegmentedControlSegmentAny);
    REG_ENUM(UISegmentedControlSegmentLeft);
    REG_ENUM(UISegmentedControlSegmentCenter);
    REG_ENUM(UISegmentedControlSegmentRight);
    REG_ENUM(UISegmentedControlSegmentAlone);
    // UIViewAutoresizing
    REG_ENUM(UIViewAutoresizingNone);
    REG_ENUM(UIViewAutoresizingFlexibleLeftMargin);
    REG_ENUM(UIViewAutoresizingFlexibleWidth);
    REG_ENUM(UIViewAutoresizingFlexibleRightMargin);
    REG_ENUM(UIViewAutoresizingFlexibleTopMargin);
    REG_ENUM(UIViewAutoresizingFlexibleHeight);
    REG_ENUM(UIViewAutoresizingFlexibleBottomMargin);


    // UIViewAnimationOptions
    REG_ENUM(UIViewAnimationOptionLayoutSubviews);
    REG_ENUM(UIViewAnimationOptionAllowUserInteraction);
    REG_ENUM(UIViewAnimationOptionBeginFromCurrentState);
    REG_ENUM(UIViewAnimationOptionRepeat);
    REG_ENUM(UIViewAnimationOptionAutoreverse);
    REG_ENUM(UIViewAnimationOptionOverrideInheritedDuration);
    REG_ENUM(UIViewAnimationOptionOverrideInheritedCurve);
    REG_ENUM(UIViewAnimationOptionAllowAnimatedContent);
    REG_ENUM(UIViewAnimationOptionShowHideTransitionViews);
    REG_ENUM(UIViewAnimationOptionOverrideInheritedOptions);

    REG_ENUM(UIViewAnimationOptionCurveEaseInOut);
    REG_ENUM(UIViewAnimationOptionCurveEaseIn);
    REG_ENUM(UIViewAnimationOptionCurveEaseOut);
    REG_ENUM(UIViewAnimationOptionCurveLinear);

    REG_ENUM(UIViewAnimationOptionTransitionNone);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromLeft);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromRight);
    REG_ENUM(UIViewAnimationOptionTransitionCurlUp);
    REG_ENUM(UIViewAnimationOptionTransitionCurlDown);
    REG_ENUM(UIViewAnimationOptionTransitionCrossDissolve);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromTop);
    REG_ENUM(UIViewAnimationOptionTransitionFlipFromBottom);


    // UIViewKeyframeAnimationOptions
    REG_ENUM(UIViewKeyframeAnimationOptionLayoutSubviews);
    REG_ENUM(UIViewKeyframeAnimationOptionAllowUserInteraction);
    REG_ENUM(UIViewKeyframeAnimationOptionBeginFromCurrentState);
    REG_ENUM(UIViewKeyframeAnimationOptionRepeat);
    REG_ENUM(UIViewKeyframeAnimationOptionAutoreverse);
    REG_ENUM(UIViewKeyframeAnimationOptionOverrideInheritedDuration);
    REG_ENUM(UIViewKeyframeAnimationOptionOverrideInheritedOptions);

    REG_ENUM(UIViewKeyframeAnimationOptionCalculationModeLinear);
    REG_ENUM(UIViewKeyframeAnimationOptionCalculationModeDiscrete);
    REG_ENUM(UIViewKeyframeAnimationOptionCalculationModePaced);
    REG_ENUM(UIViewKeyframeAnimationOptionCalculationModeCubic);
    REG_ENUM(UIViewKeyframeAnimationOptionCalculationModeCubicPaced);

    // UIUserNotificationType
    REG_ENUM(UIUserNotificationTypeNone);
    REG_ENUM(UIUserNotificationTypeBadge);
    REG_ENUM(UIUserNotificationTypeSound);
    REG_ENUM(UIUserNotificationTypeAlert);
    // UISwipeGestureRecognizerDirection
    REG_ENUM(UISwipeGestureRecognizerDirectionRight);
    REG_ENUM(UISwipeGestureRecognizerDirectionLeft);
    REG_ENUM(UISwipeGestureRecognizerDirectionUp);
    REG_ENUM(UISwipeGestureRecognizerDirectionDown);
    // UIImageOrientation
    REG_ENUM(UIImageOrientationUp);
    REG_ENUM(UIImageOrientationDown);
    REG_ENUM(UIImageOrientationLeft);
    REG_ENUM(UIImageOrientationRight);
    REG_ENUM(UIImageOrientationUpMirrored);
    REG_ENUM(UIImageOrientationDownMirrored);
    REG_ENUM(UIImageOrientationLeftMirrored);
    REG_ENUM(UIImageOrientationRightMirrored);


    // UIImageResizingMode
    REG_ENUM(UIImageResizingModeTile);
    REG_ENUM(UIImageResizingModeStretch);


    // UIImageRenderingMode
    REG_ENUM(UIImageRenderingModeAutomatic);

    REG_ENUM(UIImageRenderingModeAlwaysOriginal);
    REG_ENUM(UIImageRenderingModeAlwaysTemplate);


    // UIImagePickerControllerSourceType
    REG_ENUM(UIImagePickerControllerSourceTypePhotoLibrary);
    REG_ENUM(UIImagePickerControllerSourceTypeCamera);
    REG_ENUM(UIImagePickerControllerSourceTypeSavedPhotosAlbum);


    // UIImagePickerControllerQualityType
    REG_ENUM(UIImagePickerControllerQualityTypeHigh);
    REG_ENUM(UIImagePickerControllerQualityTypeMedium);
    REG_ENUM(UIImagePickerControllerQualityTypeLow);
    REG_ENUM(UIImagePickerControllerQualityType640x480);
    REG_ENUM(UIImagePickerControllerQualityTypeIFrame1280x720);
    REG_ENUM(UIImagePickerControllerQualityTypeIFrame960x540);


    // UIImagePickerControllerCameraCaptureMode
    REG_ENUM(UIImagePickerControllerCameraCaptureModePhoto);
    REG_ENUM(UIImagePickerControllerCameraCaptureModeVideo);


    // UIImagePickerControllerCameraDevice
    REG_ENUM(UIImagePickerControllerCameraDeviceRear);
    REG_ENUM(UIImagePickerControllerCameraDeviceFront);


    // UIImagePickerControllerCameraFlashMode
    REG_ENUM(UIImagePickerControllerCameraFlashModeOff);
    REG_ENUM(UIImagePickerControllerCameraFlashModeAuto);
    REG_ENUM(UIImagePickerControllerCameraFlashModeOn);

    // UIGestureRecognizerState
    REG_ENUM(UIGestureRecognizerStatePossible);

    REG_ENUM(UIGestureRecognizerStateBegan);
    REG_ENUM(UIGestureRecognizerStateChanged);
    REG_ENUM(UIGestureRecognizerStateEnded);
    REG_ENUM(UIGestureRecognizerStateCancelled);

    REG_ENUM(UIGestureRecognizerStateFailed);

    // Discrete Gestures – gesture recognizers that recognize a discrete event but do not report changes (for example, a tap) do not transition through the Began and Changed states and can not fail or be cancelled
    REG_ENUM(UIGestureRecognizerStateRecognized);

    // UIDeviceOrientation
    REG_ENUM(UIDeviceOrientationUnknown);
    REG_ENUM(UIDeviceOrientationPortrait);
    REG_ENUM(UIDeviceOrientationPortraitUpsideDown);
    REG_ENUM(UIDeviceOrientationLandscapeLeft);
    REG_ENUM(UIDeviceOrientationLandscapeRight);
    REG_ENUM(UIDeviceOrientationFaceUp);
    REG_ENUM(UIDeviceOrientationFaceDown);


    // UIDeviceBatteryState
    REG_ENUM(UIDeviceBatteryStateUnknown);
    REG_ENUM(UIDeviceBatteryStateUnplugged);
    REG_ENUM(UIDeviceBatteryStateCharging);
    REG_ENUM(UIDeviceBatteryStateFull);


    // UIUserInterfaceIdiom
    REG_ENUM(UIUserInterfaceIdiomUnspecified);
    REG_ENUM(UIUserInterfaceIdiomPhone);
    REG_ENUM(UIUserInterfaceIdiomPad);
    // UIDatePickerMode
    REG_ENUM(UIDatePickerModeTime);
    REG_ENUM(UIDatePickerModeDate);
    REG_ENUM(UIDatePickerModeDateAndTime);
    REG_ENUM(UIDatePickerModeCountDownTimer);
    // UIControlContentVerticalAlignment
    REG_ENUM(UIControlContentVerticalAlignmentCenter);
    REG_ENUM(UIControlContentVerticalAlignmentTop);
    REG_ENUM(UIControlContentVerticalAlignmentBottom);
    REG_ENUM(UIControlContentVerticalAlignmentFill);


    // UIControlContentHorizontalAlignment
    REG_ENUM(UIControlContentHorizontalAlignmentCenter);
    REG_ENUM(UIControlContentHorizontalAlignmentLeft);
    REG_ENUM(UIControlContentHorizontalAlignmentRight);
    REG_ENUM(UIControlContentHorizontalAlignmentFill);
    // UIButtonType
    REG_ENUM(UIButtonTypeCustom);
    REG_ENUM(UIButtonTypeSystem);

    REG_ENUM(UIButtonTypeDetailDisclosure);
    REG_ENUM(UIButtonTypeInfoLight);
    REG_ENUM(UIButtonTypeInfoDark);
    REG_ENUM(UIButtonTypeContactAdd);

    REG_ENUM(UIButtonTypeRoundedRect);
    // UIBarButtonItemStyle
    REG_ENUM(UIBarButtonItemStylePlain);
    REG_ENUM(UIBarButtonItemStyleBordered);
    REG_ENUM(UIBarButtonItemStyleDone);


    // UIBarButtonSystemItem
    REG_ENUM(UIBarButtonSystemItemDone);
    REG_ENUM(UIBarButtonSystemItemCancel);
    REG_ENUM(UIBarButtonSystemItemEdit);
    REG_ENUM(UIBarButtonSystemItemSave);
    REG_ENUM(UIBarButtonSystemItemAdd);
    REG_ENUM(UIBarButtonSystemItemFlexibleSpace);
    REG_ENUM(UIBarButtonSystemItemFixedSpace);
    REG_ENUM(UIBarButtonSystemItemCompose);
    REG_ENUM(UIBarButtonSystemItemReply);
    REG_ENUM(UIBarButtonSystemItemAction);
    REG_ENUM(UIBarButtonSystemItemOrganize);
    REG_ENUM(UIBarButtonSystemItemBookmarks);
    REG_ENUM(UIBarButtonSystemItemSearch);
    REG_ENUM(UIBarButtonSystemItemRefresh);
    REG_ENUM(UIBarButtonSystemItemStop);
    REG_ENUM(UIBarButtonSystemItemCamera);
    REG_ENUM(UIBarButtonSystemItemTrash);
    REG_ENUM(UIBarButtonSystemItemPlay);
    REG_ENUM(UIBarButtonSystemItemPause);
    REG_ENUM(UIBarButtonSystemItemRewind);
    REG_ENUM(UIBarButtonSystemItemFastForward);
    REG_ENUM(UIBarButtonSystemItemUndo);
    REG_ENUM(UIBarButtonSystemItemRedo);
    REG_ENUM(UIBarButtonSystemItemPageCurl);
    // UIStatusBarStyle
    REG_ENUM(UIStatusBarStyleDefault);
    REG_ENUM(UIStatusBarStyleLightContent);

    REG_ENUM(UIStatusBarStyleBlackTranslucent);
    REG_ENUM(UIStatusBarStyleBlackOpaque);


    // UIStatusBarAnimation
    REG_ENUM(UIStatusBarAnimationNone);
    REG_ENUM(UIStatusBarAnimationFade);
    REG_ENUM(UIStatusBarAnimationSlide);


    // UIInterfaceOrientation
    REG_ENUM(UIInterfaceOrientationUnknown);
    REG_ENUM(UIInterfaceOrientationPortrait);
    REG_ENUM(UIInterfaceOrientationPortraitUpsideDown);
    REG_ENUM(UIInterfaceOrientationLandscapeLeft);
    REG_ENUM(UIInterfaceOrientationLandscapeRight);


    // UIBackgroundRefreshStatus
    REG_ENUM(UIBackgroundRefreshStatusRestricted);
    REG_ENUM(UIBackgroundRefreshStatusDenied);
    REG_ENUM(UIBackgroundRefreshStatusAvailable);


    // UIApplicationState
    REG_ENUM(UIApplicationStateActive);
    REG_ENUM(UIApplicationStateInactive);
    REG_ENUM(UIApplicationStateBackground);

    // UIAlertViewStyle
    REG_ENUM(UIAlertViewStyleDefault);
    REG_ENUM(UIAlertViewStyleSecureTextInput);
    REG_ENUM(UIAlertViewStylePlainTextInput);
    REG_ENUM(UIAlertViewStyleLoginAndPasswordInput);


    // NSLayoutAttribute
    REG_ENUM(NSLayoutAttributeLeft);
    REG_ENUM(NSLayoutAttributeRight);
    REG_ENUM(NSLayoutAttributeTop);
    REG_ENUM(NSLayoutAttributeBottom);
    REG_ENUM(NSLayoutAttributeLeading);
    REG_ENUM(NSLayoutAttributeTrailing);
    REG_ENUM(NSLayoutAttributeWidth);
    REG_ENUM(NSLayoutAttributeHeight);
    REG_ENUM(NSLayoutAttributeCenterX);
    REG_ENUM(NSLayoutAttributeCenterY);
    REG_ENUM(NSLayoutAttributeBaseline);
    REG_ENUM(NSLayoutAttributeLastBaseline);
    REG_ENUM(NSLayoutAttributeFirstBaseline);


    REG_ENUM(NSLayoutAttributeLeftMargin);
    REG_ENUM(NSLayoutAttributeRightMargin);
    REG_ENUM(NSLayoutAttributeTopMargin);
    REG_ENUM(NSLayoutAttributeBottomMargin);
    REG_ENUM(NSLayoutAttributeLeadingMargin);
    REG_ENUM(NSLayoutAttributeTrailingMargin);
    REG_ENUM(NSLayoutAttributeCenterXWithinMargins);
    REG_ENUM(NSLayoutAttributeCenterYWithinMargins);

    REG_ENUM(NSLayoutAttributeNotAnAttribute);
    
    // NSFetchedResultsChangeType
    REG_ENUM(NSFetchedResultsChangeInsert);
    REG_ENUM(NSFetchedResultsChangeDelete);
    REG_ENUM(NSFetchedResultsChangeMove);
    REG_ENUM(NSFetchedResultsChangeUpdate);
#else
#endif
}

int luaopen_luaoc_enum(lua_State* L) {
    lua_newtable(L);

    reg_def_enum(L);

    return 1;
}
