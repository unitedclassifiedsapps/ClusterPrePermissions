//
//  ClusterPrePermissions.m
//  ClusterPrePermissions
//
//  Created by Rizwan Sattar on 4/7/14.
//  Copyright (c) 2014 Cluster Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

typedef NS_ENUM(NSInteger, ClusterTitleType) {
    ClusterTitleTypeRequest,
    ClusterTitleTypeDeny
};


#import "ClusterPrePermissions.h"

#import <AddressBook/AddressBook.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <EventKit/EventKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
//at least iOS 9 code here
@import Contacts;
#endif

NSString *const ClusterPrePermissionsDidAskForPushNotifications = @"ClusterPrePermissionsDidAskForPushNotifications";

@interface ClusterPrePermissions () <UIAlertViewDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIAlertView *preAVPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler avPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *prePhotoPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler photoPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preContactPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler contactPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preEventPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler eventPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preLocationPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler locationPermissionCompletionHandler;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (assign, nonatomic) ClusterLocationAuthorizationType locationAuthorizationType;
@property (assign, nonatomic) ClusterPushNotificationType requestedPushNotificationTypes;
@property (strong, nonatomic) UIAlertView *prePushNotificationPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler pushNotificationPermissionCompletionHandler;

@end

static ClusterPrePermissions *__sharedInstance;

@implementation ClusterPrePermissions

+ (instancetype) sharedPermissions
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[ClusterPrePermissions alloc] init];
    });
    return __sharedInstance;
}

+ (ClusterAuthorizationStatus) AVPermissionAuthorizationStatusForMediaType:(NSString*)mediaType
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case AVAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case AVAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) cameraPermissionAuthorizationStatus
{
    return [ClusterPrePermissions AVPermissionAuthorizationStatusForMediaType:AVMediaTypeVideo];
}

+ (ClusterAuthorizationStatus) microphonePermissionAuthorizationStatus
{
    return [ClusterPrePermissions AVPermissionAuthorizationStatusForMediaType:AVMediaTypeAudio];
}

+ (ClusterAuthorizationStatus) photoPermissionAuthorizationStatus
{
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    switch (status) {
        case ALAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case ALAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case ALAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}


+ (ClusterAuthorizationStatus) contactsPermissionAuthorizationStatus
{
    ClusterContactsAuthorizationType authType;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    //at least iOS 9 code here
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    authType = (ClusterContactsAuthorizationType)status;
#else
    //lower than iOS 9 code here
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    authType = (ClusterContactsAuthorizationType)status;
#endif
    switch (authType) {
        case ClusterContactsAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;
            
        case ClusterContactsAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;
            
        case ClusterContactsAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;
            
        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}


+ (ClusterAuthorizationStatus) eventPermissionAuthorizationStatus:(ClusterEventAuthorizationType)eventType
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:
                  [[ClusterPrePermissions sharedPermissions] EKEquivalentEventType:eventType]];
    switch (status) {
        case EKAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case EKAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case EKAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) locationPermissionAuthorizationStatus
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return ClusterAuthorizationStatusAuthorized;

        case kCLAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case kCLAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) pushNotificationPermissionAuthorizationStatus
{
    BOOL didAskForPermission = [[NSUserDefaults standardUserDefaults] boolForKey:ClusterPrePermissionsDidAskForPushNotifications];

    if (didAskForPermission) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
            // iOS8+
            if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
                return ClusterAuthorizationStatusAuthorized;
            } else {
                return ClusterAuthorizationStatusDenied;
            }
        } else {

            // Add compiler check to avoid warnings, if deployment target >= 8.0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
            // iOS 7
            if ([[UIApplication sharedApplication] enabledRemoteNotificationTypes] == UIRemoteNotificationTypeNone) {
                return ClusterAuthorizationStatusDenied;
            } else {
                return ClusterAuthorizationStatusAuthorized;
            }
#else
            // Impossible state to be in: iOS 8 device, but somehow doesn't respond to isRegisteredForRemoteNotifications?
            return ClusterAuthorizationStatusDenied;
#endif
        }
    } else {
        return ClusterAuthorizationStatusUnDetermined;
    }
}

#pragma mark - Push Notification Permissions Help

- (void) showPushNotificationPermissionsWithType:(ClusterPushNotificationType)requestedType
                                           title:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showPushNotificationInViewController:nil
                           permissionsWithType:requestedType
                                         title:requestTitle
                                       message:message
                               denyButtonTitle:denyButtonTitle
                              grantButtonTitle:grantButtonTitle
                             completionHandler:completionHandler];
}

- (void) showPushNotificationInViewController:(UIViewController *)viewController
                          permissionsWithType:(ClusterPushNotificationType)requestedType
                                        title:(NSString *)requestTitle
                                      message:(NSString *)message
                              denyButtonTitle:(NSString *)denyButtonTitle
                             grantButtonTitle:(NSString *)grantButtonTitle
                            completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Enable Push Notifications?";
    }
    denyButtonTitle = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    ClusterAuthorizationStatus status = [ClusterPrePermissions pushNotificationPermissionAuthorizationStatus];
    if (status == ClusterAuthorizationStatusUnDetermined) {
        self.pushNotificationPermissionCompletionHandler = completionHandler;
        if ([UIAlertController class]
            && [viewController isKindOfClass:[UIViewController class]]) {
            
            [self presentAlertControllerInViewController:viewController
                                               withTitle:requestTitle
                                                 message:message
                                         denyButtonTitle:denyButtonTitle
                                       denyButtionAction:^(UIAlertAction *action) {
                                           [self firePushNotificationPermissionCompletionHandler];
                                       }
                                        grantButtonTitle:grantButtonTitle
                                      grantButtionAction:^(UIAlertAction *action) {
                                          [self showActualPushNotificationPermissionAlert];
                                      }];
            
        } else {
            self.requestedPushNotificationTypes = requestedType;
            self.prePushNotificationPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                                     message:message
                                                                                    delegate:self
                                                                           cancelButtonTitle:denyButtonTitle
                                                                           otherButtonTitles:grantButtonTitle, nil];
            [self.prePushNotificationPermissionAlertView show];
        }
    } else {
        if (completionHandler) {
            completionHandler((status == ClusterAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}

- (void) showActualPushNotificationPermissionAlert
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        // iOS8+
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)self.requestedPushNotificationTypes
                                                                                 categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        // Add compiler check to avoid warnings, if deployment target >= 8.0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationType)self.requestedPushNotificationTypes];
#endif
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES
                                            forKey:ClusterPrePermissionsDidAskForPushNotifications];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidBecomeActive
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [self firePushNotificationPermissionCompletionHandler];
}


- (void) firePushNotificationPermissionCompletionHandler
{
    ClusterAuthorizationStatus status = [ClusterPrePermissions pushNotificationPermissionAuthorizationStatus];
    if (self.pushNotificationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ClusterAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ClusterAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ClusterAuthorizationStatusUnDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        }
        self.pushNotificationPermissionCompletionHandler((status == ClusterAuthorizationStatusAuthorized),
                                                         userDialogResult,
                                                         systemDialogResult);
        self.pushNotificationPermissionCompletionHandler = nil;
    }
}


#pragma mark - AV Permissions Help

- (void) showAVPermissionsWithType:(ClusterAVAuthorizationType)mediaType
                             title:(NSString *)requestTitle
                           message:(NSString *)message
                   denyButtonTitle:(NSString *)denyButtonTitle
                  grantButtonTitle:(NSString *)grantButtonTitle
                 completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showAVPermissionsInViewController:nil
                                   withType:mediaType
                                      title:requestTitle
                                    message:message
                            denyButtonTitle:denyButtonTitle
                           grantButtonTitle:grantButtonTitle
                          completionHandler:completionHandler];
}

- (void) showAVPermissionsInViewController:(UIViewController *)viewController
                                  withType:(ClusterAVAuthorizationType)mediaType
                                     title:(NSString *)requestTitle
                                   message:(NSString *)message
                           denyButtonTitle:(NSString *)denyButtonTitle
                          grantButtonTitle:(NSString *)grantButtonTitle
                         completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        switch (mediaType) {
            case ClusterAVAuthorizationTypeCamera:
                requestTitle = @"Access Camera?";
                break;
                
            default:
                requestTitle = @"Access Microphone?";
                break;
        }
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:[self AVEquivalentMediaType:mediaType]];
    if (status == AVAuthorizationStatusNotDetermined) {
        self.avPermissionCompletionHandler = completionHandler;
        if ([UIAlertController class]
            && [viewController isKindOfClass:[UIViewController class]]) {
            
            [self presentAlertControllerInViewController:viewController
                                               withTitle:requestTitle
                                                 message:message
                                         denyButtonTitle:denyButtonTitle
                                       denyButtionAction:^(UIAlertAction *action) {
                                           [self fireAVPermissionCompletionHandlerWithType:mediaType];
                                       }
                                        grantButtonTitle:grantButtonTitle
                                      grantButtionAction:^(UIAlertAction *action) {
                                          [self showActualAVPermissionAlertWithType:mediaType];
                                      }];
            
        } else {
            self.preAVPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                       message:message
                                                                      delegate:self
                                                             cancelButtonTitle:denyButtonTitle
                                                             otherButtonTitles:grantButtonTitle, nil];
            self.preAVPermissionAlertView.tag = mediaType;
            [self.preAVPermissionAlertView show];
        }
    } else {
        if (completionHandler) {
            completionHandler((status == AVAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showCameraPermissionsWithTitle:(NSString *)requestTitle
                                message:(NSString *)message
                        denyButtonTitle:(NSString *)denyButtonTitle
                       grantButtonTitle:(NSString *)grantButtonTitle
                      completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showCameraPermissionsInViewController:nil
                                      withTitle:requestTitle
                                        message:message
                                denyButtonTitle:denyButtonTitle
                               grantButtonTitle:grantButtonTitle
                              completionHandler:completionHandler];
}

- (void) showCameraPermissionsInViewController:(UIViewController *)viewController
                                     withTitle:(NSString *)requestTitle
                                       message:(NSString *)message
                               denyButtonTitle:(NSString *)denyButtonTitle
                              grantButtonTitle:(NSString *)grantButtonTitle
                             completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showAVPermissionsInViewController:viewController
                                   withType:ClusterAVAuthorizationTypeCamera
                                      title:requestTitle
                                    message:message
                            denyButtonTitle:denyButtonTitle
                           grantButtonTitle:grantButtonTitle
                          completionHandler:completionHandler];
}


- (void) showMicrophonePermissionsWithTitle:(NSString *)requestTitle
                                    message:(NSString *)message
                            denyButtonTitle:(NSString *)denyButtonTitle
                           grantButtonTitle:(NSString *)grantButtonTitle
                          completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showMicrophonePermissionsInViewController:nil
                                          withTitle:requestTitle
                                            message:message
                                    denyButtonTitle:denyButtonTitle
                                   grantButtonTitle:grantButtonTitle
                                  completionHandler:completionHandler];
}

- (void) showMicrophonePermissionsInViewController:(UIViewController *)viewController
                                         withTitle:(NSString *)requestTitle
                                           message:(NSString *)message
                                   denyButtonTitle:(NSString *)denyButtonTitle
                                  grantButtonTitle:(NSString *)grantButtonTitle
                                 completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showAVPermissionsInViewController:viewController
                                   withType:ClusterAVAuthorizationTypeMicrophone
                                      title:requestTitle
                                    message:message
                            denyButtonTitle:denyButtonTitle
                           grantButtonTitle:grantButtonTitle
                          completionHandler:completionHandler];
}

- (void) showActualAVPermissionAlertWithType:(ClusterAVAuthorizationType)mediaType
{
    [AVCaptureDevice requestAccessForMediaType:[self AVEquivalentMediaType:mediaType]
                             completionHandler:^(BOOL granted) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     [self fireAVPermissionCompletionHandlerWithType:mediaType];
                                 });
                             }];
}


- (void) fireAVPermissionCompletionHandlerWithType:(ClusterAVAuthorizationType)mediaType
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:[self AVEquivalentMediaType:mediaType]];
    if (self.avPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == AVAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == AVAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == AVAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == AVAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.avPermissionCompletionHandler((status == AVAuthorizationStatusAuthorized),
                                           userDialogResult,
                                           systemDialogResult);
        self.avPermissionCompletionHandler = nil;
    }
}


- (NSString*)AVEquivalentMediaType:(ClusterAVAuthorizationType)mediaType
{
    if (mediaType == ClusterAVAuthorizationTypeCamera) {
        return AVMediaTypeVideo;
    }
    else {
        return AVMediaTypeAudio;
    }
}

#pragma mark - Photo Permissions Help

- (void) showPhotoPermissionsWithTitle:(NSString *)requestTitle
                               message:(NSString *)message
                       denyButtonTitle:(NSString *)denyButtonTitle
                      grantButtonTitle:(NSString *)grantButtonTitle
                     completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showPhotoPermissionsInViewController:nil
                                     withTitle:requestTitle
                                       message:message
                               denyButtonTitle:denyButtonTitle
                              grantButtonTitle:grantButtonTitle
                             completionHandler:completionHandler];
}

- (void) showPhotoPermissionsInViewController:(UIViewController *)viewController
                                    withTitle:(NSString *)requestTitle
                                      message:(NSString *)message
                              denyButtonTitle:(NSString *)denyButtonTitle
                             grantButtonTitle:(NSString *)grantButtonTitle
                            completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler;

{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Photos?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusNotDetermined) {
        self.photoPermissionCompletionHandler = completionHandler;
        if ([UIAlertController class]
            && [viewController isKindOfClass:[UIViewController class]]) {
            
            [self presentAlertControllerInViewController:viewController
                                               withTitle:requestTitle
                                                 message:message
                                         denyButtonTitle:denyButtonTitle
                                       denyButtionAction:^(UIAlertAction *action) {
                                           [self firePhotoPermissionCompletionHandler];
            }
                                        grantButtonTitle:grantButtonTitle
                                      grantButtionAction:^(UIAlertAction *action) {
                                          [self showActualPhotoPermissionAlert];
            }];
            
        } else {
            self.prePhotoPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                          message:message
                                                                         delegate:self
                                                                cancelButtonTitle:denyButtonTitle
                                                                otherButtonTitles:grantButtonTitle, nil];
            [self.prePhotoPermissionAlertView show];
        }
        
    } else {
        if (completionHandler) {
            completionHandler((status == ALAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualPhotoPermissionAlert
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // Got access! Show login
        [self firePhotoPermissionCompletionHandler];
        *stop = YES;
    } failureBlock:^(NSError *error) {
        // User denied access
        [self firePhotoPermissionCompletionHandler];
    }];
}


- (void) firePhotoPermissionCompletionHandler
{
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (self.photoPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ALAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == ALAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ALAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ALAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.photoPermissionCompletionHandler((status == ALAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.photoPermissionCompletionHandler = nil;
    }
}


#pragma mark - Contact Permissions Help
/*!
* @discussion get the authorization status of accessing contacts. It handles both uses of Contacts framework iOS 9+ or AddressBook fremwork < iOS 9
* @param ClusterContactsAuthorizationType
*/
-(ClusterContactsAuthorizationType)getContactsAuthorizationType{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    //at least iOS 9 code here
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    return (ClusterContactsAuthorizationType)status;
#else
    //lower than iOS 9 code here
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    return (ClusterContactsAuthorizationType)status;
#endif
}

- (void) showContactsPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showContactsPermissionsInViewController:nil
                                        withTitle:requestTitle
                                          message:message
                                  denyButtonTitle:denyButtonTitle
                                 grantButtonTitle:grantButtonTitle
                                completionHandler:completionHandler];
}

- (void) showContactsPermissionsInViewController:(UIViewController *)viewController
                                       withTitle:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Contacts?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    ClusterContactsAuthorizationType status = [self getContactsAuthorizationType];
    
    
    if (status == ClusterContactsAuthorizationStatusNotDetermined) {
        self.contactPermissionCompletionHandler = completionHandler;
        if ([UIAlertController class]
            && [viewController isKindOfClass:[UIViewController class]]) {
            
            [self presentAlertControllerInViewController:viewController
                                               withTitle:requestTitle
                                                 message:message
                                         denyButtonTitle:denyButtonTitle
                                       denyButtionAction:^(UIAlertAction *action) {
                                           [self fireContactPermissionCompletionHandler];
                                       }
                                        grantButtonTitle:grantButtonTitle
                                      grantButtionAction: ^(UIAlertAction *action) {
                                          [self showActualContactPermissionAlert];
                                      }];
            
        } else {
            self.preContactPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                            message:message
                                                                           delegate:self
                                                                  cancelButtonTitle:denyButtonTitle
                                                                  otherButtonTitles:grantButtonTitle, nil];
            [self.preContactPermissionAlertView show];
        }
    } else {
        if (completionHandler) {
            completionHandler(status == ClusterContactsAuthorizationStatusAuthorized,
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualContactPermissionAlert
{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    //at least iOS 9 code here
    CNContactStore *contactsStore = [[CNContactStore alloc] init];
    [contactsStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireContactPermissionCompletionHandler];
        });
    }];
#else
    //lower than iOS 9 code here
    CFErrorRef error = nil;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, &error);
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireContactPermissionCompletionHandler];
        });
    });
#endif
    
}


- (void) fireContactPermissionCompletionHandler
{
    ClusterContactsAuthorizationType status = [self getContactsAuthorizationType];
    if (self.contactPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ClusterContactsAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == ClusterContactsAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ClusterContactsAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ClusterContactsAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.contactPermissionCompletionHandler((status == ClusterContactsAuthorizationStatusAuthorized),
                                                userDialogResult,
                                                systemDialogResult);
        self.contactPermissionCompletionHandler = nil;
    }
}


#pragma mark - Event Permissions Help


- (void) showEventPermissionsWithType:(ClusterEventAuthorizationType)eventType
                                Title:(NSString *)requestTitle
                              message:(NSString *)message
                      denyButtonTitle:(NSString *)denyButtonTitle
                     grantButtonTitle:(NSString *)grantButtonTitle
                    completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showEventPermissionsInViewController:nil
                                      withType:eventType
                                         title:requestTitle
                                       message:message
                               denyButtonTitle:denyButtonTitle
                              grantButtonTitle:grantButtonTitle
                             completionHandler:completionHandler];
}

- (void) showEventPermissionsInViewController:(UIViewController *)viewController
                                     withType:(ClusterEventAuthorizationType)eventType
                                        title:(NSString *)requestTitle
                                      message:(NSString *)message
                              denyButtonTitle:(NSString *)denyButtonTitle
                             grantButtonTitle:(NSString *)grantButtonTitle
                            completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        switch (eventType) {
            case ClusterEventAuthorizationTypeEvent:
                requestTitle = @"Access Calendar?";
                break;
                
            default:
                requestTitle = @"Access Reminders?";
                break;
        }
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:[self EKEquivalentEventType:eventType]];
    if (status == EKAuthorizationStatusNotDetermined) {
        self.eventPermissionCompletionHandler = completionHandler;
        if ([UIAlertController class]
            && [viewController isKindOfClass:[UIViewController class]]) {
            
            [self presentAlertControllerInViewController:viewController
                                               withTitle:requestTitle
                                                 message:message
                                         denyButtonTitle:denyButtonTitle
                                       denyButtionAction:^(UIAlertAction *action) {
                                           [self fireEventPermissionCompletionHandler:eventType];
                                       }
                                        grantButtonTitle:grantButtonTitle
                                      grantButtionAction:^(UIAlertAction *action) {
                                          [self showActualEventPermissionAlert:eventType];
                                      }];
            
        } else {
            self.preEventPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                          message:message
                                                                         delegate:self
                                                                cancelButtonTitle:denyButtonTitle
                                                                otherButtonTitles:grantButtonTitle, nil];
            self.preEventPermissionAlertView.tag = eventType;
            [self.preEventPermissionAlertView show];
        }
    } else {
        if (completionHandler) {
            completionHandler((status == EKAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}

- (void) showActualEventPermissionAlert:(ClusterEventAuthorizationType)eventType
{
    EKEventStore *aStore = [[EKEventStore alloc] init];
    [aStore requestAccessToEntityType:[self EKEquivalentEventType:eventType] completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireEventPermissionCompletionHandler:eventType];
        });
    }];
}


- (void) fireEventPermissionCompletionHandler:(ClusterEventAuthorizationType)eventType
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:[self EKEquivalentEventType:eventType]];
    if (self.eventPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == EKAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == EKAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == EKAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == EKAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.eventPermissionCompletionHandler((status == EKAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.eventPermissionCompletionHandler = nil;
    }
}

- (NSUInteger)EKEquivalentEventType:(ClusterEventAuthorizationType)eventType {
    if (eventType == ClusterEventAuthorizationTypeEvent) {
        return EKEntityTypeEvent;
    }
    else {
        return EKEntityTypeReminder;
    }
}

#pragma mark - Location Permission Help



- (void) showLocationPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showLocationPermissionsInViewController:nil
                                        withTitle:requestTitle
                                          message:message
                                  denyButtonTitle:denyButtonTitle
                                 grantButtonTitle:grantButtonTitle
                                completionHandler:completionHandler];
}

- (void) showLocationPermissionsInViewController:(UIViewController *)viewController
                                       withTitle:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showLocationPermissionsInViewController:viewController
                             forAuthorizationType:ClusterLocationAuthorizationTypeAlways
                                        withTitle:requestTitle
                                          message:message
                                  denyButtonTitle:denyButtonTitle
                                 grantButtonTitle:grantButtonTitle
                                completionHandler:completionHandler];
}

- (void) showLocationPermissionsForAuthorizationType:(ClusterLocationAuthorizationType)authorizationType
                                               title:(NSString *)requestTitle
                                             message:(NSString *)message
                                     denyButtonTitle:(NSString *)denyButtonTitle
                                    grantButtonTitle:(NSString *)grantButtonTitle
                                   completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showLocationPermissionsInViewController:nil
                             forAuthorizationType:authorizationType
                                        withTitle:requestTitle
                                          message:message
                                  denyButtonTitle:denyButtonTitle
                                 grantButtonTitle:grantButtonTitle
                                completionHandler:completionHandler];
}

- (void) showLocationPermissionsInViewController:(UIViewController *)viewController
                            forAuthorizationType:(ClusterLocationAuthorizationType)authorizationType
                                       withTitle:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Location?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.locationPermissionCompletionHandler = completionHandler;
        if ([UIAlertController class]
            && [viewController isKindOfClass:[UIViewController class]]) {
            
            [self presentAlertControllerInViewController:viewController
                                               withTitle:requestTitle
                                                 message:message
                                         denyButtonTitle:denyButtonTitle
                                       denyButtionAction:^(UIAlertAction *action) {
                                           [self fireLocationPermissionCompletionHandler];
                                       }
                                        grantButtonTitle:grantButtonTitle
                                      grantButtionAction:^(UIAlertAction *action) {
                                          [self showActualLocationPermissionAlert];
                                      }];
            
        } else {
            self.locationAuthorizationType = authorizationType;
            self.preLocationPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                             message:message
                                                                            delegate:self
                                                                   cancelButtonTitle:denyButtonTitle
                                                                   otherButtonTitles:grantButtonTitle, nil];
            [self.preLocationPermissionAlertView show];
        }
        
    } else {
        if (completionHandler) {
            completionHandler(([self locationAuthorizationStatusPermitsAccess:status]),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualLocationPermissionAlert
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    if (self.locationAuthorizationType == ClusterLocationAuthorizationTypeAlways &&
        [self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {

        [self.locationManager requestAlwaysAuthorization];

    } else if (self.locationAuthorizationType == ClusterLocationAuthorizationTypeWhenInUse &&
               [self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {

        [self.locationManager requestWhenInUseAuthorization];
    }

    [self.locationManager startUpdatingLocation];
}


- (void) fireLocationPermissionCompletionHandler
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (self.locationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kCLAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if ([self locationAuthorizationStatusPermitsAccess:status]) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == kCLAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == kCLAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.locationPermissionCompletionHandler(([self locationAuthorizationStatusPermitsAccess:status]),
                                                 userDialogResult,
                                                 systemDialogResult);
        self.locationPermissionCompletionHandler = nil;
    }
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation], self.locationManager = nil;
    }
}

- (BOOL)locationAuthorizationStatusPermitsAccess:(CLAuthorizationStatus)authorizationStatus
{
    return authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ||
    authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse;
}

#pragma mark CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self fireLocationPermissionCompletionHandler];
    }
}


#pragma mark - UIAlertViewDelegate


- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.preAVPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, jerk.
            [self fireAVPermissionCompletionHandlerWithType:alertView.tag];
        } else {
            // User granted access, now show the REAL permissions dialog
            [self showActualAVPermissionAlertWithType:alertView.tag];
        }

        self.preAVPermissionAlertView = nil;
    } else if (alertView == self.prePhotoPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, jerk.
            [self firePhotoPermissionCompletionHandler];
        } else {
            // User granted access, now show the REAL permissions dialog
            [self showActualPhotoPermissionAlert];
        }

        self.prePhotoPermissionAlertView = nil;
    } else if (alertView == self.preContactPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireContactPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real contacts access
            [self showActualContactPermissionAlert];
        }
    } else if (alertView == self.preEventPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireEventPermissionCompletionHandler:alertView.tag];
        } else {
            // User granted access, now try to trigger the real contacts access
            [self showActualEventPermissionAlert:alertView.tag];
        }
    } else if (alertView == self.preLocationPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireLocationPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real location access
            [self showActualLocationPermissionAlert];
        }
    } else if (alertView == self.prePushNotificationPermissionAlertView) {
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self firePushNotificationPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real location access
            [self showActualPushNotificationPermissionAlert];
        }
    }
}

#pragma mark - Titles

- (NSString *)titleFor:(ClusterTitleType)titleType fromTitle:(NSString *)title
{
    switch (titleType) {
        case ClusterTitleTypeDeny:
            title = (title.length == 0) ? @"Not Now" : title;
            break;
        case ClusterTitleTypeRequest:
            title = (title.length == 0) ? @"Give Access" : title;
            break;
        default:
            title = @"";
            break;
    }
    return title;
}

#pragma mrak - UIAlertController

- (void)presentAlertControllerInViewController:(UIViewController *)viewController
                                     withTitle:(NSString *)title
                                       message:(NSString *)message
                               denyButtonTitle:(NSString *)denyButtonTitle
                             denyButtionAction:(void (^)(UIAlertAction *action))denyButtionAction
                              grantButtonTitle:(NSString *)grantButtonTitle
                            grantButtionAction:(void (^)(UIAlertAction *action))grantButtionAction
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *denyAlertAction = [UIAlertAction actionWithTitle:denyButtonTitle
                                                              style:UIAlertActionStyleCancel
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                if (denyButtionAction) {
                                                                    denyButtionAction(action);
                                                                }
                                                            }];
    
    [alertController addAction:denyAlertAction];
    
    UIAlertAction *grantAlertAction = [UIAlertAction actionWithTitle:grantButtonTitle
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 if (grantButtionAction) {
                                                                     grantButtionAction(action);
                                                                 }
                                                             }];
    
    [alertController addAction:grantAlertAction];
    
    [viewController presentViewController:alertController
                                 animated:YES
                               completion:nil];
}

@end
