//
//  ProcessAndSignOperation.m
//  iAppSigner
//
//  Created by Alan Marcan on 27.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "ProcessAndSignOperation.h"
#import "FileCopyHelper.h"


#define ERR_LOG(error) ({if (!self.isCancelled && !!error) DLog(@"%@", error);})
#define CHK_CANCEL ({if (self.isCancelled) return NO;})


@interface ProcessAndSignOperation()
{
	NSFileManager *_fm;
	NSString *_tmpPath;
	NSString *_bundlePath;
	NSString *_bundleID;
	NSString *_appExecPath;
	NSString *_tmpIPAFilePath;
	NSDictionary *_appInfoPlist;
	NSTask *_execTask;
}

@property NSString *certName;
@property NSString *provProfilePath;
@property NSDictionary *provProfileDict;
@property NSString *ipaFilePath;
@property BOOL updateEntitlements;
@property ProcessAndSignFinishBlock finishBlock;

@end


@implementation ProcessAndSignOperation

static NSString *tmpRootDir = @"iAppSigner";
// unzip
static NSString *unzipQuietArg = @"-q";
static NSString *unzipSkipArg = @"-x";
static NSString *unzipSkipArgMacParam = @"__MACOSX/*";
static NSString *unzipSkipArgITMetaParam = @"iTunesMetadata.plist";
static NSString *unzipSkipArgDSSParam = @".DS_Store";
static NSString *unzipSkipArgZipCommParam = @".ZipComment";
// sign
static NSString *codesignForceArg = @"-f";
static NSString *codesignSignArg = @"-s";
static NSString *codesignEntitlementsArg = @"--entitlements";
static NSString *ipaPayloadDir = @"Payload";
static NSString *appExtension = @"app";
static NSString *codeSignatureDir = @"_CodeSignature";
static NSString *embeddedProvProfileName = @"embedded.mobileprovision";
static NSString *entitlementsTemplateFile = @"EntitlementsTemplate.plist";
static NSString *infoPlistFile = @"Info.plist";
static NSString *entitlementsAppIDKey = @"application-identifier";
static NSString *entitlementsDevKeysPrefix = @"com.apple.developer";
static NSString *entitlementsKVStoreIDKey = @"com.apple.developer.ubiquity-kvstore-identifier";
static NSString *entitlementsAppIDPrefixPlaceholder = @"$(AppIdentifierPrefix)";
static NSString *entitlementsTeamIDPrefixPlaceholder = @"$(TeamIdentifierPrefix)";
static NSString *entitlementsTeamIDPlaceholder = @"$(TeamIdentifier)";
static NSString *entitlementsBundleIDPlaceholder = @"$(CFBundleIdentifier)";
static NSString *entitlementsPrefixSeparator = @".";
static NSString *entitlementsAsteriskBundleIDPlaceholder = @"*";
static NSString *archEntExtension = @"xcent";
static NSString *entitlementsExtension = @"entitlements";
static NSString *frameworksDir = @"Frameworks";
static NSString *plugInsDir = @"PlugIns";
static NSString *armFileSearchStr = @"(for architecture arm";
static NSString *signedIPAFileSuffix = @"-signed";
// zip
static NSString *zipQuietArg = @"-q";
static NSString *zipRecursiveArg = @"-r";
static NSString *zipIPAFileExt = @"ipa";
static NSString *zipCurrDirArg = @".";


#pragma mark - init

+ (instancetype)operationWithCertificate:(NSString *)certName
						 provProfilePath:(NSString *)provProfilePath
						 provProfileDict:(NSDictionary *)provProfileDict
							 ipaFilePath:(NSString *)ipaFilePath
					  updateEntitlements:(BOOL)updateEntitlements
						  andFinishBlock:(ProcessAndSignFinishBlock)finishBlock
{
	NSAssert(certName.length > 0, @"Cert name is empty!");
	NSAssert(provProfilePath.length > 0, @"Prov. profile path is empty!");
	NSAssert(ipaFilePath.length > 0, @"IPA file path is empty!");

	ProcessAndSignOperation *op = [ProcessAndSignOperation new];
	op.certName = certName;
	op.provProfilePath = provProfilePath;
	op.provProfileDict = provProfileDict;
	op.ipaFilePath = ipaFilePath;
	op.updateEntitlements = updateEntitlements;
	op.finishBlock = finishBlock;
	return op;
}


- (instancetype)init
{
	self = [super init];

	if (self)
	{
		_fm = [NSFileManager defaultManager];
	}

	return self;
}


#pragma mark - NSOperation

- (void)main
{
	[LogHelper log:LSTR(@"ProcessAndSign.Log.Start")];

	if (!self.isCancelled && ![self setupWorkingDirectory])
	{
		[self terminateAndCleanWithSuccess:NO];
		return;
	}

	if (!self.isCancelled && ![self extractIPAFile])
	{
		[self terminateAndCleanWithSuccess:NO];
		return;
	}

	if (!self.isCancelled && ![self setupEntitlementsAndSign])
	{
		[self terminateAndCleanWithSuccess:NO];
		return;
	}

	if (!self.isCancelled && ![self fixExecPermission])
	{
		[self terminateAndCleanWithSuccess:NO];
		return;
	}

	if (!self.isCancelled && ![self compressPayloadAndCopyIPAFile])
	{
		[self terminateAndCleanWithSuccess:NO];
		return;
	}

	if (self.isCancelled)
	{
		return;
	}

	[self cleanup];
	[self finish:YES];
}


- (void)cancel
{
	[self terminateAndCleanWithSuccess:YES];
	[super cancel];
}


#pragma mark - Private methods
#pragma mark Steps methods

- (BOOL)setupWorkingDirectory
{
	[LogHelper log:LSTR(@"ProcessAndSign.Log.SetupTmp")];

	_tmpPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:tmpRootDir] stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	DLog(@"Working path: %@", _tmpPath);

	NSError *error = nil;
	[_fm createDirectoryAtPath:_tmpPath withIntermediateDirectories:YES attributes:nil error:&error];
	CHK_CANCEL;

	if (!!error)
	{
		DLog(@"%@", error);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorSetupTmp")];
		return NO;
	}

	if (![_fm changeCurrentDirectoryPath:_tmpPath])
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorOpenTmp")];
		return NO;
	}

	[LogHelper log:LSTR(@"ProcessAndSign.Log.OKTmp")];

	return YES;
}


- (BOOL)extractIPAFile
{
	[LogHelper log:LSTR(@"ProcessAndSign.Log.ExtIPA")];

	NSString *tmpIPAFilePath = [_tmpPath stringByAppendingPathComponent:_ipaFilePath.lastPathComponent];

	NSError *error = nil;
	[_fm copyItemAtPath:_ipaFilePath toPath:tmpIPAFilePath error:&error];
	CHK_CANCEL;

	if (!!error)
	{
		DLog(@"%@", error);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorCopyExtIPA")];
		return NO;
	}

	NSPipe *errPipe = [NSPipe pipe];

	@try
	{
		_execTask = [NSTask new];
		_execTask.launchPath = kUnzipCmd;
		_execTask.arguments = @[unzipQuietArg,
								tmpIPAFilePath,
								unzipSkipArg,
								unzipSkipArgMacParam,
								unzipSkipArgITMetaParam,
								unzipSkipArgDSSParam,
								unzipSkipArgZipCommParam];
		_execTask.standardOutput = [NSPipe pipe];
		_execTask.standardError = errPipe;
		[_execTask launch];
		[_execTask waitUntilExit];
	}
	@catch (NSException *exception)
	{
		DLog(@"%@", exception);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorEndedExtIPA")];
		return NO;
	}

	CHK_CANCEL;
	DLog(@"Unzip task finished with status: %ld, reason: %ld", (long)_execTask.terminationStatus, (long)_execTask.terminationReason);

	if (_execTask.terminationStatus > 1)
	{
#ifdef DEBUG
		NSData *errData = [errPipe.fileHandleForReading readDataToEndOfFile];

		if (errData.length > 0)
		{
			DLog(@"%@", [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding]);
		}
#endif

		switch (_execTask.terminationStatus)
		{
			case 2:
			case 51:
			case 81:
			case 82:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorInvalidExtIPAFrmt"), _execTask.terminationStatus];
				break;
			case 3:
			case 4:
			case 5:
			case 6:
			case 7:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorMemoryExtIPAFrmt"), _execTask.terminationStatus];
				break;
			case 50:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorDiskExtIPAFrmt"), _execTask.terminationStatus];
				break;
			default:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorFailedExtIPAFrmt"), _execTask.terminationStatus];
				break;
		}

		return NO;
	}

	error = nil;
	[_fm removeItemAtPath:tmpIPAFilePath error:&error];
	ERR_LOG(error);

	[LogHelper log:LSTR(@"ProcessAndSign.Log.OKExtIPA")];

	return YES;
}


- (BOOL)setupEntitlementsAndSign
{
// Find paths
	[LogHelper log:LSTR(@"ProcessAndSign.Log.ChkIPA")];

	NSString *payloadDir = [_tmpPath stringByAppendingPathComponent:ipaPayloadDir];
	DLog(@"IPA Payload path: %@", payloadDir);

	NSString *bundleDir = nil;
	NSError *error = nil;

	for (NSString *pathName in [_fm contentsOfDirectoryAtPath:payloadDir error:&error])
	{
		CHK_CANCEL;

		if ([pathName.pathExtension isEqualToString:appExtension])
		{
			bundleDir = pathName.lastPathComponent;
			DLog(@"App bundle dir: %@", bundleDir);
			break;
		}
	}

	ERR_LOG(error);

	if (bundleDir.length == 0)
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorBundleDirChkIPAFrmt"), ipaPayloadDir, appExtension];
		return NO;
	}

	_bundlePath = [payloadDir stringByAppendingPathComponent:bundleDir];

	_appInfoPlist = [NSDictionary dictionaryWithContentsOfFile:[_bundlePath stringByAppendingPathComponent:infoPlistFile]];

	if (_appInfoPlist.count == 0)
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorInfoPlistChkIPAFrmt"), infoPlistFile];
		return NO;
	}

	NSString *appExecName = CLASS_SAFE_VALUE(_appInfoPlist[(NSString *)kCFBundleExecutableKey], [NSString class], nil);

	if (appExecName.length > 0)
	{
		_appExecPath = [_bundlePath stringByAppendingPathComponent:appExecName];
		BOOL isDir = NO;

		if (![_fm fileExistsAtPath:_appExecPath isDirectory:&isDir] || isDir)
		{
			[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorAppExecChkIPAFrmt"), appExecName];
			return NO;
		}
	}

	[LogHelper log:LSTR(@"ProcessAndSign.Log.OKChkIPAFrmt")];


// Remove recursive all _CodeSignature dirs from bundle dir
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.RemSigDirs")];

	error = nil;
	NSDirectoryEnumerator *dirEnum = [_fm enumeratorAtPath:_bundlePath];
	NSString *pathName;
	NSUInteger count = 0;

	while (pathName = [dirEnum nextObject])
	{
		if ([pathName.lastPathComponent isEqualToString:codeSignatureDir])
		{
			NSString *path = [_bundlePath stringByAppendingPathComponent:pathName];
			BOOL isDir = NO;

			if (!self.isCancelled && [_fm fileExistsAtPath:path isDirectory:&isDir] && isDir)
			{
				DLog(@"Found \"%@\" dir at path: %@", codeSignatureDir, path);
				error = nil;
				[_fm removeItemAtPath:path error:&error];
				ERR_LOG(error);

				if (!error)
				{
					count++;
				}
			}
		}

		CHK_CANCEL;
	}

	if (count > 0)
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKFoundRemSigDirsFrmt"), count];
	}
	else
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKNotFoundRemSigDirs")];
	}


// Copy embeded prov. profile into bundle dir
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.EmbProvCopy")];

	NSString *embProvProfilePath = [_bundlePath stringByAppendingPathComponent:embeddedProvProfileName];

	if ([_fm fileExistsAtPath:embProvProfilePath isDirectory:NULL])
	{
		error = nil;
		[_fm removeItemAtPath:embProvProfilePath error:&error];
		ERR_LOG(error);
	}

	error = nil;
	[_fm copyItemAtPath:_provProfilePath toPath:embProvProfilePath error:&error];

	if (!!error)
	{
		DLog(@"%@", error);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorEmbProvCopyFrmt"), embeddedProvProfileName];
		return NO;
	}

	[LogHelper log:LSTR(@"ProcessAndSign.Log.OKEmbProvCopy")];


// Copy/merge app entitlements in bundle dir
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.SetupEnts")];

	_bundleID = CLASS_SAFE_VALUE(_appInfoPlist[(NSString *)kCFBundleIdentifierKey], [NSString class], nil);

	if (_bundleID.length == 0)
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorBundleIDSetupEntsFrmt"), infoPlistFile];
		return NO;
	}

	BOOL updateEntitlements = YES;
	NSString *entFilePath = [self setupEntitlementsAtPath:_bundlePath isExtension:NO updateEntitlements:&updateEntitlements];

	if (updateEntitlements && entFilePath.length == 0)
	{
		return NO;
	}

	[LogHelper log:LSTR(@"ProcessAndSign.Log.OKSetupEnts")];


// Sign frameworks if exists
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.FindSignLibs")];

	NSString *frameworksPath = [_bundlePath stringByAppendingPathComponent:frameworksDir];
	BOOL isDir = NO;

	if ([_fm fileExistsAtPath:frameworksPath isDirectory:&isDir] && isDir)
	{
		error = nil;
		for (NSString *pathName in [_fm contentsOfDirectoryAtPath:frameworksPath error:&error])
		{
			[LogHelper log:LSTR(@"ProcessAndSign.Log.SigningFindSignLibsFrmt"), pathName];

			if (!self.isCancelled && ![self signAtPath:[frameworksPath stringByAppendingPathComponent:pathName] withEntFilePath:nil])
			{
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorFindSignLibs")];
				return NO;
			}

			CHK_CANCEL;
		}

		ERR_LOG(error);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKFindSignLibs")];
	}
	else
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKNotFoundFindSignLibs")];
	}


// Sign app extenstions if exists
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.FindSignExts")];

	NSString *plugInsPath = [_bundlePath stringByAppendingPathComponent:plugInsDir];

	if ([_fm fileExistsAtPath:plugInsPath isDirectory:&isDir] && isDir)
	{
		error = nil;
		for (NSString *pathName in [_fm contentsOfDirectoryAtPath:plugInsPath error:&error])
		{
			[LogHelper log:LSTR(@"ProcessAndSign.Log.SetupFindSignExtsFrmt"), pathName];
			NSString *extenstionPath = [plugInsPath stringByAppendingPathComponent:pathName];
			BOOL updateEntitlements = YES;
			NSString *extenstionEntFilePath = [self setupEntitlementsAtPath:extenstionPath isExtension:YES updateEntitlements:&updateEntitlements];

			if (!self.isCancelled && updateEntitlements && extenstionEntFilePath.length == 0)
			{
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorSetupFindSignExts")];
				return NO;
			}

			[LogHelper log:LSTR(@"ProcessAndSign.Log.SigningFindSignExtsFrmt"), pathName];

			if (!self.isCancelled && ![self signAtPath:extenstionPath withEntFilePath:extenstionEntFilePath])
			{
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorSigningFindSignExts")];
				return NO;
			}

			CHK_CANCEL;
		}

		ERR_LOG(error);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKFindSignExts")];
	}
	else
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKNotFoundFindSignExts")];
	}


// Sign other binaries if exists
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.FindSignBins")];

	count = 0;
	error = nil;
	for (NSString *pathName in [_fm contentsOfDirectoryAtPath:_bundlePath error:&error])
	{
		NSString *binPath = [_bundlePath stringByAppendingPathComponent:pathName];
		BOOL isDir = NO;

		if (!self.isCancelled && ![binPath isEqualToString:_appExecPath] && [_fm fileExistsAtPath:binPath isDirectory:&isDir] && !isDir)
		{
			NSPipe *outPipe = [NSPipe pipe];
			NSPipe *errPipe = [NSPipe pipe];

			@try
			{
				_execTask = [NSTask new];
				_execTask.launchPath = kFileCmd;
				_execTask.arguments = @[binPath];
				_execTask.standardOutput = outPipe;
				_execTask.standardError = errPipe;
				[_execTask launch];
				[_execTask waitUntilExit];
			}
			@catch (NSException *exception)
			{
				DLog(@"%@", exception);
				return NO;
			}

			CHK_CANCEL;
			NSData *dataRead = [outPipe.fileHandleForReading readDataToEndOfFile];

			if (_execTask.terminationStatus == 0 && dataRead.length > 0)
			{
				NSString *outStr = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];

				if ([outStr containsString:armFileSearchStr])
				{
					[LogHelper log:LSTR(@"ProcessAndSign.Log.SigningFindSignBinsFrmt"), pathName];

					if (!self.isCancelled && ![self signAtPath:binPath withEntFilePath:nil])
					{
						[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorSigningFindSignBins")];
						return NO;
					}

					count++;
				}
			}
			else
			{
				DLog(@"ERROR: File check task finished with status: %ld, reason: %ld", (long)_execTask.terminationStatus, (long)_execTask.terminationReason);
#ifdef DEBUG
				NSData *errData = [errPipe.fileHandleForReading readDataToEndOfFile];

				if (errData.length > 0)
				{
					DLog(@"%@", [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding]);
				}
#endif
			}
		}

		CHK_CANCEL;
	}

	ERR_LOG(error);

	if (count > 0)
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKFindSignBins")];
	}
	else
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKNotFoundFindSignBins")];
	}


// Sign app
	CHK_CANCEL;

	[LogHelper log:LSTR(@"ProcessAndSign.Log.SignApp")];

	if (![self signAtPath:_bundlePath withEntFilePath:entFilePath])
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorSignApp")];
		return NO;
	}

	[LogHelper log:LSTR(@"ProcessAndSign.Log.OKSignApp")];

	return YES;
}


- (BOOL)fixExecPermission
{
	CHK_CANCEL;

	if (_appExecPath.length > 0)
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.FixExecPerm")];
		NSError *error = nil;
		[_fm setAttributes:@{NSFilePosixPermissions: [NSNumber numberWithShort:0755]} ofItemAtPath:_appExecPath error:&error];
		CHK_CANCEL;
		ERR_LOG(error);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKFixExecPerm")];
	}

	return YES;
}


- (BOOL)compressPayloadAndCopyIPAFile
{
	[LogHelper log:LSTR(@"ProcessAndSign.Log.CreatingIPA")];

	NSString *tmpIPAName = [_tmpPath.lastPathComponent stringByAppendingPathExtension:zipIPAFileExt];
	NSPipe *errPipe = [NSPipe pipe];

	@try
	{
		_execTask = [NSTask new];
		_execTask.launchPath = kZipCmd;
		_execTask.arguments = @[zipQuietArg,
								zipRecursiveArg,
								tmpIPAName,
								zipCurrDirArg];
		_execTask.standardOutput = [NSPipe pipe];
		_execTask.standardError = errPipe;
		[_execTask launch];
		[_execTask waitUntilExit];
	}
	@catch (NSException *exception)
	{
		DLog(@"%@", exception);
		[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorEndedCreatingIPA")];
		return NO;
	}

	CHK_CANCEL;
	DLog(@"Zip task finished with status: %ld, reason: %ld", (long)_execTask.terminationStatus, (long)_execTask.terminationReason);

	if (_execTask.terminationStatus != 0)
	{
#ifdef DEBUG
		NSData *errData = [errPipe.fileHandleForReading readDataToEndOfFile];

		if (errData.length > 0)
		{
			DLog(@"%@", [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding]);
		}
#endif

		switch (_execTask.terminationStatus)
		{
			case 4:
			case 8:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorMemoryCreatingIPAFrmt"), _execTask.terminationStatus];
				break;
			case 10:
			case 14:
			case 15:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorDiskCreatingIPAFrmt"), _execTask.terminationStatus];
				break;
			default:
				[LogHelper log:LSTR(@"ProcessAndSign.Log.ErrorFailedCreatingIPAFrmt"), _execTask.terminationStatus];
				break;
		}

		return NO;
	}

	NSString *signedIPAName = [[_ipaFilePath.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:signedIPAFileSuffix];
	NSString *dstPath = [[[_ipaFilePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:signedIPAName] stringByAppendingPathExtension:_ipaFilePath.pathExtension];
	NSError *error = nil;
	[FileCopyHelper atomicFileCopyAtPath:tmpIPAName
								  toPath:dstPath
								   error:&error];
	CHK_CANCEL;

	if (!!error)
	{
		DLog(@"%@", error);
		error = nil;
		_tmpIPAFilePath = [FileCopyHelper atomicFileCopyAtPath:tmpIPAName
														toPath:[[NSTemporaryDirectory() stringByAppendingPathComponent:tmpRootDir]
																stringByAppendingPathComponent:tmpIPAName]
														 error:&error];
		ERR_LOG(error);

		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKNoSaveCreatingIPA")];
	}
	else
	{
		[LogHelper log:LSTR(@"ProcessAndSign.Log.OKSavedCreatingIPA")];
	}

	return YES;
}


#pragma mark Entitlements util methods

- (NSString *)setupEntitlementsAtPath:(NSString *)path isExtension:(BOOL)isExtension updateEntitlements:(BOOL *)updateEntitlements
{
	NSString *entFilePath = nil;
	NSString *archEntFilePath = nil;
	NSMutableDictionary *entitlements = nil;
	NSError *error = nil;

	for (NSString *pathName in [_fm contentsOfDirectoryAtPath:path error:&error])
	{
		if (self.isCancelled)
		{
			return nil;
		}

		if ([pathName.pathExtension isEqualToString:archEntExtension])
		{
			archEntFilePath = [path stringByAppendingPathComponent:pathName];
			DLog(@"Archived expanded entitlements file found at path: %@", archEntFilePath);
			NSMutableDictionary *archEnt = [self processEntitlementsAtPath:archEntFilePath isExtension:isExtension updateEntitlements:updateEntitlements];

			if (archEnt.count > 0)
			{

				NSError *err = nil;
				[_fm removeItemAtPath:archEntFilePath error:&err];
				ERR_LOG(error);

				[archEnt writeToFile:archEntFilePath atomically:YES];
			}

			if (entFilePath.length == 0)
			{
				entFilePath = archEntFilePath;
			}
		}
		else if ([pathName.pathExtension isEqualToString:entitlementsExtension])
		{
			entFilePath = [path stringByAppendingPathComponent:pathName];
			DLog(@"Entitlements file found at path: %@", entFilePath);
			entitlements = [self processEntitlementsAtPath:entFilePath isExtension:isExtension updateEntitlements:updateEntitlements];

			if (entitlements.count > 0)
			{
				error = nil;
				[_fm removeItemAtPath:entFilePath error:&error];
				ERR_LOG(error);
			}
		}
	}

	ERR_LOG(error);

	if (!isExtension)
	{
		if (entFilePath.length == 0)
		{
			NSString *entFileName = [[path.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:entitlementsExtension];
			entFilePath = [path stringByAppendingPathComponent:entFileName];
			[LogHelper log:LSTR(@"ProcessAndSign.Log.NewSetupEntsFrmt"), entFileName];

			error = nil;
			NSMutableString *entTemplateStr = [[NSMutableString alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:entitlementsTemplateFile
																															  ofType:nil]
																					 encoding:NSUTF8StringEncoding
																						error:&error];
			ERR_LOG(error);

			[self replaceEntitlementsString:entTemplateStr withBundleID:_bundleID andAppIDPref:_provProfileDict[kProvProfileAppIDPrefixKey][0]];
			error = nil;
			entitlements = [NSPropertyListSerialization propertyListWithData:[entTemplateStr dataUsingEncoding:NSUTF8StringEncoding]
																	 options:NSPropertyListMutableContainersAndLeaves
																	  format:nil
																	   error:&error];
			ERR_LOG(error);
		}

		if (self.isCancelled)
		{
			return nil;
		}

		if (entitlements.count > 0)
		{
			[entitlements writeToFile:entFilePath atomically:YES];
		}
	}

	return entFilePath;
}


- (NSMutableDictionary *)processEntitlementsAtPath:(NSString *)entFilePath isExtension:(BOOL)isExtension updateEntitlements:(BOOL *)updateEntitlements
{
	if (entFilePath.length == 0)
	{
		return nil;
	}

	NSMutableDictionary *entitlements = [[NSMutableDictionary alloc] initWithContentsOfFile:entFilePath];

	if (entitlements.count == 0)
	{
		DLog(@"ERROR: Error loading entitlements file: %@", entFilePath);
		return nil;
	}

	NSString *bundleID = _bundleID;
	NSString *entAppID = entitlements[entitlementsAppIDKey];
	NSString *entAppIDPrefix = nil;

	if (entAppID.length != 0)
	{
		NSString *entBundleID = nil;
		entAppIDPrefix = [self appIDPrefixForString:entAppID parsedBundleID:&entBundleID];

		if (entBundleID.length > 0)
		{
			bundleID = entBundleID;
		}
	}
	else
	{
		NSString *kvStoreID = entitlements[entitlementsKVStoreIDKey];

		if (kvStoreID.length > 0)
		{
			NSString *entBundleID = nil;
			entAppIDPrefix = [self appIDPrefixForString:kvStoreID parsedBundleID:&entBundleID];

			if (entBundleID.length > 0)
			{
				bundleID = entBundleID;
			}
		}
	}

	if (self.isCancelled)
	{
		return nil;
	}

	entitlements = [_provProfileDict[kProvProfileEntitlementsKey] mutableCopy];
	NSString *appIDPref = _provProfileDict[kProvProfileAppIDPrefixKey][0];
	NSString *appID = [(NSString *)CLASS_SAFE_VALUE(entitlements[entitlementsAppIDKey], [NSString class], nil)
					   stringByReplacingOccurrencesOfString:entitlementsAsteriskBundleIDPlaceholder withString:bundleID];

	if (!_updateEntitlements)
	{
		if ((isExtension && [entAppIDPrefix isEqualToString:appIDPref])
			|| (!isExtension && [entAppID isEqualToString:appID]))
		{
			[LogHelper log:LSTR(@"ProcessAndSign.Log.FoundMatchSetupEnts")];
			*updateEntitlements = NO;
			return nil;
		}
		else
		{
			DLog(@"No matching application identifier in current entitlements.");
		}
	}

	if (self.isCancelled)
	{
		return nil;
	}

	DLog(@"Updating entitlements.");

	[((NSDictionary *)_provProfileDict[kProvProfileEntitlementsKey]).allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
	{
		if (self.isCancelled)
		{
			*stop = YES;
			return;
		}

		if ([key hasPrefix:entitlementsDevKeysPrefix])
		{
			[entitlements removeObjectForKey:key];
		}
	}];

	if (self.isCancelled)
	{
		return nil;
	}

	return [self processEntDict:entitlements withBundleID:bundleID andAppIDPref:appIDPref];
}


- (NSMutableDictionary *)processEntDict:(NSDictionary *)entDic withBundleID:(NSString *)bundleID andAppIDPref:(NSString *)appIDPref
{
	NSMutableDictionary *mutDict = [entDic mutableCopy];

	for (NSString *key in entDic.allKeys)
	{
		if (self.isCancelled)
		{
			return mutDict;
		}

		id val = entDic[key];

		if ([val isKindOfClass:[NSString class]])
		{
			NSMutableString *mutVal = [(NSString *)val mutableCopy];
			[self replaceEntitlementsString:mutVal withBundleID:bundleID andAppIDPref:appIDPref];
			mutDict[key] = mutVal;
		}
		else if ([val isKindOfClass:[NSDictionary class]])
		{
			val = [self processEntDict:entDic withBundleID:bundleID andAppIDPref:appIDPref];
			mutDict[key] = val;
		}
		else if ([val isKindOfClass:[NSArray class]])
		{
			val = [self processEntArray:(NSArray *)val inDict:mutDict atKey:key withBundleID:bundleID andAppIDPref:appIDPref];
			mutDict[key] = val;
		}
	}

	return mutDict;
}


- (NSArray *)processEntArray:(NSArray *)entArray inDict:(NSMutableDictionary *)dict atKey:(NSString *)key withBundleID:(NSString *)bundleID andAppIDPref:(NSString *)appIDPref
{
	NSMutableArray *mutArray = [entArray mutableCopy];

	[entArray enumerateObjectsUsingBlock:^(id val, NSUInteger idx, BOOL *stop)
	{
		if (self.isCancelled)
		{
			*stop = YES;
			return;
		}

		if ([val isKindOfClass:[NSString class]])
		{
			NSMutableString *mutVal = [(NSString *)val mutableCopy];
			[self replaceEntitlementsString:mutVal withBundleID:bundleID andAppIDPref:appIDPref];
			mutArray[idx] = mutVal;
		}
		else if ([val isKindOfClass:[NSDictionary class]])
		{
			val = [self processEntDict:dict withBundleID:bundleID andAppIDPref:appIDPref];
			mutArray[idx] = val;
		}
		else if ([val isKindOfClass:[NSArray class]])
		{
			val = [self processEntArray:(NSArray *)val inDict:dict atKey:key withBundleID:bundleID andAppIDPref:appIDPref];
			mutArray[idx] = val;
		}
	}];

	return mutArray;
}


- (NSString *)appIDPrefixForString:(NSString *)string parsedBundleID:(NSString **)parsedID
{
	NSString *prefix = nil;

	if (string.length > 0)
	{
		NSRange prefixRange = [string rangeOfString:entitlementsPrefixSeparator options:0];

		if (prefixRange.location != NSNotFound)
		{
			prefix = [string stringByReplacingCharactersInRange:NSMakeRange(prefixRange.location, string.length - prefixRange.location) withString:kEmptyString];

			if ((prefixRange.location + 1) < string.length)
			{
				*parsedID = [string stringByReplacingCharactersInRange:NSMakeRange(0, prefixRange.location + 1) withString:kEmptyString];
			}
		}
	}

	return prefix;
}


- (void)replaceEntitlementsString:(NSMutableString *)string withBundleID:(NSString *)bundleID andAppIDPref:(NSString *)appIDPref
{
	NSString *teamID = _provProfileDict[kProvProfileTeamIdentifierKey][0];
	[string replaceOccurrencesOfString:entitlementsAppIDPrefixPlaceholder withString:[appIDPref stringByAppendingString:entitlementsPrefixSeparator] options:NSLiteralSearch range:NSMakeRange(0, string.length)];
	[string replaceOccurrencesOfString:entitlementsTeamIDPrefixPlaceholder withString:[teamID stringByAppendingString:entitlementsPrefixSeparator] options:NSLiteralSearch range:NSMakeRange(0, string.length)];
	[string replaceOccurrencesOfString:entitlementsTeamIDPlaceholder withString:teamID options:NSLiteralSearch range:NSMakeRange(0, string.length)];
	[string replaceOccurrencesOfString:entitlementsBundleIDPlaceholder withString:bundleID options:NSLiteralSearch range:NSMakeRange(0, string.length)];
	[string replaceOccurrencesOfString:entitlementsAsteriskBundleIDPlaceholder withString:bundleID options:0 range:NSMakeRange(0, string.length)];
}


- (BOOL)signAtPath:(NSString *)path withEntFilePath:(NSString *)entFilePath
{
	NSMutableArray *arguments = [NSMutableArray arrayWithArray:@[codesignForceArg,
																 codesignSignArg,
																 _certName]];

	if (entFilePath.length > 0)
	{
		[arguments addObjectsFromArray:@[codesignEntitlementsArg, entFilePath]];
	}

	[arguments addObject:path];
	NSPipe *errPipe = [NSPipe pipe];

	@try
	{
		_execTask = [NSTask new];
		_execTask.launchPath = kCodesignCmd;
		_execTask.arguments = arguments;
		_execTask.standardOutput = [NSPipe pipe];
		_execTask.standardError = errPipe;
		[_execTask launch];
		[_execTask waitUntilExit];
	}
	@catch (NSException *exception)
	{
		DLog(@"%@", exception);
		return NO;
	}

	CHK_CANCEL;
	DLog(@"Signing task finished with status: %ld, reason: %ld", (long)_execTask.terminationStatus, (long)_execTask.terminationReason);

	if (_execTask.terminationStatus != 0)
	{
#ifdef DEBUG
		NSData *errData = [errPipe.fileHandleForReading readDataToEndOfFile];

		if (errData.length > 0)
		{
			DLog(@"%@", [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding]);
		}
#endif

		return NO;
	}

	return YES;
}


#pragma mark Operation helper methods

- (void)terminateAndCleanWithSuccess:(BOOL)success
{
	if (self.isCancelled)
	{
		return;
	}

	if (_execTask.isRunning)
	{
		[_execTask terminate];
	}

	[self cleanup];
	[self finish:success];
}


- (void)cleanup
{
	if ([_fm fileExistsAtPath:_tmpPath isDirectory:NULL])
	{
		NSError *error = nil;
		[_fm removeItemAtPath:_tmpPath error:&error];
		ERR_LOG(error);
	}
}


- (void)finish:(BOOL)success
{
	if (_finishBlock)
	{
		ProcessAndSignFinishBlock finishBlock = _finishBlock;

		dispatch_async(dispatch_get_main_queue(), ^
		{
			if (!self.isCancelled)
			{
				[LogHelper log:LSTR(@"ProcessAndSign.Log.Done")];
				finishBlock(success, _tmpIPAFilePath);
			}
		});
	}

	_finishBlock = nil;
}

@end
