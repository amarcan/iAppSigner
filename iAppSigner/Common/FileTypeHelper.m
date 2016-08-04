//
//  FileTypeHelper.m
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "FileTypeHelper.h"


@implementation FileTypeHelper

+ (BOOL)isExtensionProvProfile:(NSString *)extension
{
	CFStringRef utiType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(extension), NULL);

	if (!utiType)
	{
		return NO;
	}

	BOOL isIPA = UTTypeEqual(utiType, (__bridge CFStringRef)kProvProfileUTI);
	CFRelease(utiType);
	return isIPA;
}


+ (BOOL)isExtensionIPAFile:(NSString *)extension
{
	CFStringRef utiType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(extension), NULL);

	if (!utiType)
	{
		return NO;
	}

	BOOL isIPA = UTTypeEqual(utiType, (__bridge CFStringRef)kIPAFileUTI);
	CFRelease(utiType);
	return isIPA;
}

@end
