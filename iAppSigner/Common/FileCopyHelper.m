//
//  FileCopyHelper.m
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "FileCopyHelper.h"


@implementation FileCopyHelper

#pragma mark - Public methods

+ (NSString *)atomicFileCopyAtPath:(NSString *)path toPath:(NSString *)toPath error:(NSError **)error
{
	*error = nil;
	return [self.class atomicFileCopyAtPath:path
									 toPath:toPath
								   filename:toPath.lastPathComponent
							   currentCount:1
									  error:error];
}


#pragma mark - Private methods

+ (NSString *)atomicFileCopyAtPath:(NSString *)path
							toPath:(NSString *)toPath
						  filename:(NSString *)filename
					  currentCount:(NSUInteger)currentCount
							 error:(NSError **)error
{
	if (!!*error)
	{
		return nil;
	}
	else if (currentCount >= kAtomicFileCopyMaxCount)
	{
		*error = [NSError errorWithDomain:kAtomicFileCopyErrorDomain code:1 userInfo:nil];
		return nil;
	}

	NSFileManager *fm = [NSFileManager defaultManager];

	if (![fm fileExistsAtPath:toPath])
	{
		[fm copyItemAtPath:path toPath:toPath error:error];
	}
	else
	{
		NSString *atomicFilename = [[filename stringByDeletingPathExtension] stringByAppendingFormat:@" (%lu)", currentCount];
		return [self.class atomicFileCopyAtPath:path
										 toPath:[[[toPath stringByDeletingLastPathComponent]
												  stringByAppendingPathComponent:atomicFilename]
												 stringByAppendingPathExtension:filename.pathExtension]
									   filename:filename
								   currentCount:++currentCount
										  error:error];
	}

	return toPath;
}

@end
