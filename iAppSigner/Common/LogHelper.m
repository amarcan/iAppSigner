//
//  LogHelper.m
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "LogHelper.h"


@implementation LogHelper

#pragma mark - Public methods

+ (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2)
{
	va_list args;
	va_start(args, format);
	NSString *log = [[[NSString alloc] initWithFormat:format arguments:args] stringByAppendingString:@"\n"];
	va_end(args);

	NSLog(@"%@", log);
	dispatch_async(dispatch_get_main_queue(), ^
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kLogAddedNotification
															object:nil
														  userInfo:@{kLogNotificationUserInfokey: log}];
	});
}


+ (void)clearLog
{
	DLog(@"Log cleared");
	dispatch_async(dispatch_get_main_queue(), ^
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kLogClearedNotification
															object:nil];
	});
}

@end
