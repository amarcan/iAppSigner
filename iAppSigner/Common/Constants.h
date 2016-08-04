//
//  Constants.h
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>

// String
FOUNDATION_EXPORT NSString *const kEmptyString;

// File types
FOUNDATION_EXPORT NSString *const kIPAFileUTI;
FOUNDATION_EXPORT NSString *const kProvProfileUTI;

// Prov. profile dictionary keys
FOUNDATION_EXPORT NSString *const kProvProfileAppIDPrefixKey;
FOUNDATION_EXPORT NSString *const kProvProfileCertsKey;
FOUNDATION_EXPORT NSString *const kProvProfileEntitlementsKey;
FOUNDATION_EXPORT NSString *const kProvProfileNameKey;
FOUNDATION_EXPORT NSString *const kProvProfileTeamIdentifierKey;

// Log notifications
FOUNDATION_EXPORT NSString *const kLogAddedNotification;
FOUNDATION_EXPORT NSString *const kLogClearedNotification;
FOUNDATION_EXPORT NSString *const kLogNotificationUserInfokey;

// Mandatory tools
FOUNDATION_EXPORT NSString *const kCodesignCmd;
FOUNDATION_EXPORT NSString *const kFileCmd;
FOUNDATION_EXPORT NSString *const kUnzipCmd;
FOUNDATION_EXPORT NSString *const kZipCmd;

// Atomic file copy
FOUNDATION_EXPORT NSUInteger const kAtomicFileCopyMaxCount;
FOUNDATION_EXPORT NSString *const kAtomicFileCopyErrorDomain;
