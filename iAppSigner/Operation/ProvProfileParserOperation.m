//
//  ProvProfileParserOperation.m
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "ProvProfileParserOperation.h"


@interface ProvProfileParserOperation()

@property NSString *provProfilePath;
@property ProvProfileParserFinishBlock finishBlock;

@end


@implementation ProvProfileParserOperation

NSString *const kPlistStartStr = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>";
NSString *const kPlistEndStr = @"</plist>";


#pragma mark - init

+ (instancetype)operationWithProvProfilePath:(NSString *)provProfilePath
							  andFinishBlock:(ProvProfileParserFinishBlock)finishBlock
{
	ProvProfileParserOperation *op = [ProvProfileParserOperation new];
	op.provProfilePath = provProfilePath;
	op.finishBlock = finishBlock;
	return op;
}


#pragma mark - NSOperation

- (void)main
{
	[LogHelper log:LSTR(@"ProvProfileParser.Log.Start")];

	NSError *error = nil;
	NSString *fileString = [NSString stringWithContentsOfFile:_provProfilePath encoding:NSASCIIStringEncoding error:&error];

	if (error)
	{
		DLog(@"%@", error);
		[self finish:nil];
	}

	NSScanner *scanner = [[NSScanner alloc] initWithString:fileString];
	NSString *plistString = nil;

	if ([scanner scanUpToString:kPlistStartStr intoString:NULL])
	{
		if ([scanner scanUpToString:kPlistEndStr intoString:&plistString])
		{
			plistString = [plistString stringByAppendingString:kPlistEndStr];
		}
	}

	if (self.isCancelled)
	{
		return;
	}

	NSDictionary *profileDict = nil;

	if (plistString.length > 0)
	{
		NSData *strData = [plistString dataUsingEncoding:NSASCIIStringEncoding];

		if (strData.length > 0)
		{
			profileDict = [[[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] propertyList];
		}
	}

	[self finish:[self verify:profileDict]];
}


#pragma mark - Private methods

- (NSDictionary *)verify:(NSDictionary *)profileDict
{
	if (profileDict.count == 0)
	{
		[LogHelper log:LSTR(@"ProvProfileParser.Log.Invalid")];
		return nil;
	}

	[LogHelper log:LSTR(@"ProvProfileParser.Log.Found")];

	if (((NSArray *)CLASS_SAFE_VALUE(profileDict[kProvProfileAppIDPrefixKey], [NSArray class], nil)).count == 0)
	{
		[LogHelper log:LSTR(@"ProvProfileParser.Log.ErrorAppID")];
		return nil;
	}

	if (((NSArray *)CLASS_SAFE_VALUE(profileDict[kProvProfileCertsKey], [NSArray class], nil)).count == 0)
	{
		[LogHelper log:LSTR(@"ProvProfileParser.Log.ErrorCerts")];
		return nil;
	}

	if (((NSDictionary *)CLASS_SAFE_VALUE(profileDict[kProvProfileEntitlementsKey], [NSDictionary class], nil)).count == 0)
	{
		[LogHelper log:LSTR(@"ProvProfileParser.Log.ErrorEnt")];
		return nil;
	}

	if (((NSString *)CLASS_SAFE_VALUE(profileDict[kProvProfileNameKey], [NSString class], nil)).length == 0)
	{
		[LogHelper log:LSTR(@"ProvProfileParser.Log.ErrorName")];
		return nil;
	}

	if (((NSArray *)CLASS_SAFE_VALUE(profileDict[kProvProfileTeamIdentifierKey], [NSArray class], nil)).count == 0)
	{
		[LogHelper log:LSTR(@"ProvProfileParser.Log.ErrorTeamID")];
		return nil;
	}

	[LogHelper log:LSTR(@"ProvProfileParser.Log.OKFrmt"),  profileDict[kProvProfileNameKey]];

	return profileDict;
}


- (void)finish:(NSDictionary *)provProfileDict
{
	if (!self.isCancelled && _finishBlock)
	{
		ProvProfileParserFinishBlock finishBlock = _finishBlock;

		dispatch_async(dispatch_get_main_queue(), ^
		{
			if (!self.isCancelled)
			{
				[LogHelper log:LSTR(@"ProvProfileParser.Log.Done")];
				finishBlock(provProfileDict);
			}
		});
	}

	_finishBlock = nil;
}

@end
