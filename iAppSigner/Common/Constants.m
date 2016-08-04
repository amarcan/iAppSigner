//
//  Constants.m
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "Constants.h"

// String
NSString *const kEmptyString = @"";

// File types
NSString *const kIPAFileUTI = @"com.apple.itunes.ipa";
NSString *const kProvProfileUTI = @"com.apple.mobileprovision";

// Prov. profile dictionary keys
NSString *const kProvProfileNameKey = @"Name";
NSString *const kProvProfileCertsKey = @"DeveloperCertificates";
NSString *const kProvProfileEntitlementsKey = @"Entitlements";
NSString *const kProvProfileAppIDPrefixKey = @"ApplicationIdentifierPrefix";
NSString *const kProvProfileTeamIdentifierKey = @"TeamIdentifier";

// Log notifications
NSString *const kLogAddedNotification = @"kLogAddedNotification";
NSString *const kLogClearedNotification = @"kLogClearedNotification";
NSString *const kLogNotificationUserInfokey = @"kLogNotificationUserInfokey";

// Mandatory tools
NSString *const kCodesignCmd = @"/usr/bin/codesign";
NSString *const kFileCmd = @"/usr/bin/file";
NSString *const kUnzipCmd = @"/usr/bin/unzip";
NSString *const kZipCmd = @"/usr/bin/zip";

// Atomic copy file
NSUInteger const kAtomicFileCopyMaxCount = 1024;
NSString *const kAtomicFileCopyErrorDomain = @"AtomicCopyFileErrorDomain";
