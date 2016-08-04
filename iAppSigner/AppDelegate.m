//
//  AppDelegate.m
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "AppDelegate.h"


@interface AppDelegate()
{
	BOOL _appShouldTerminate;
	__block NSTask *_checkCmdTask;
}

@end


@implementation AppDelegate

NSString *const kOperationCountKey = @"operationCount";


#pragma mark - Notifications

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[self checkMandatoryCommands];

	_mainQueue = [NSOperationQueue new];
	[_mainQueue addObserver:self forKeyPath:kOperationCountKey options:0 context:NULL];
}


#pragma mark - NSApplicationDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
	return YES;
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if (_checkCmdTask.isRunning)
	{
		[_checkCmdTask terminate];
	}

	if (_mainQueue.operationCount > 0)
	{
		_appShouldTerminate = YES;
		[_mainQueue cancelAllOperations];
		return NSTerminateLater;
	}

	return NSTerminateNow;
}


#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary<NSString*, id> *)change
					   context:(void *)context;
{
	if (object == _mainQueue && [keyPath isEqualToString:kOperationCountKey])
	{
		if (_appShouldTerminate && _mainQueue.operationCount == 0)
		{
			[NSApp replyToApplicationShouldTerminate:YES];
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath
							 ofObject:object
							   change:change
							  context:context];
	}
}


#pragma mark - Private methods

- (void)checkMandatoryCommands
{
	NSString *checkCmdArg = @"--help";

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
	{
		[@[kCodesignCmd, kFileCmd, kZipCmd, kUnzipCmd] enumerateObjectsUsingBlock:^(NSString *cmd, NSUInteger idx, BOOL *stop)
		{
			if (_appShouldTerminate)
			{
				*stop = YES;
				return;
			}

			BOOL error = NO;

			@try
			{
				_checkCmdTask = [NSTask new];
				_checkCmdTask.launchPath = cmd;
				_checkCmdTask.arguments = @[checkCmdArg];
				_checkCmdTask.standardOutput = [NSPipe pipe];
				_checkCmdTask.standardError = [NSPipe pipe];
				[_checkCmdTask launch];
				[_checkCmdTask waitUntilExit];
				DLog(@"%@ command exit state: %d", cmd, _checkCmdTask.terminationStatus);

				if (_checkCmdTask.terminationReason != NSTaskTerminationReasonExit)
				{
					DLog(@"ERROR: Failed to launch command: %@", cmd);
					error = YES;
				}
			}
			@catch (NSException *exception)
			{
				DLog(@"ERROR: Unable to launch command: %@ - %@", cmd, exception);
				error = YES;
			}

			if (error)
			{
				dispatch_async(dispatch_get_main_queue(), ^
				{
					NSAlert *alert = [NSAlert new];
					alert.alertStyle = NSCriticalAlertStyle;
					alert.messageText = LSTR(@"MandatoryCmdCheck.Alert.ErrorMessage");
					alert.informativeText = [NSString stringWithFormat:LSTR(@"MandatoryCmdCheck.Alert.ErrorInfoFrmt"), cmd];
					[alert addButtonWithTitle:LSTR(@"Common.Exit")];
					[alert runModal];
					[_window close];
				});

				*stop = YES;
			}
		}];
	});
}

@end
