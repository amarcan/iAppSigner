//
//  CertificatesLoaderOperation.m
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import "CertificatesLoaderOperation.h"
#import <Security/Security.h>


@interface CertificatesLoaderOperation()

@property NSArray *certificates;
@property CertificatesLoaderFinishBlock finishBlock;

@end


@implementation CertificatesLoaderOperation


#pragma mark - init

+ (instancetype)operationWithProvProfileDict:(NSDictionary *)profileDict
							  andFinishBlock:(CertificatesLoaderFinishBlock)finishBlock
{
	CertificatesLoaderOperation *op = [CertificatesLoaderOperation new];
	op.certificates = profileDict[kProvProfileCertsKey];
	op.finishBlock = finishBlock;
	return op;
}


#pragma mark - NSOperation

- (void)main
{
	[LogHelper log:LSTR(@"CertificatesLoader.Log.Start")];

	NSArray *keychainCerts = [self keychainCertificates];

	if (keychainCerts.count == 0)
	{
		[LogHelper log:LSTR(@"CertificatesLoader.Log.ErrorCertsNotFound")];
		[self finish:nil];
		return;
	}

	NSMutableArray *avaiableCertificates = [[NSMutableArray alloc] initWithCapacity:_certificates.count];

	[_certificates enumerateObjectsUsingBlock:^(NSData *certData, NSUInteger idx, BOOL *stop)
	{
		if (self.isCancelled)
		{
			*stop = YES;
			return;
		}

		 SecCertificateRef cert = SecCertificateCreateWithData(NULL, (CFDataRef)certData);

		 if (!cert)
		 {
			 [LogHelper log:LSTR(@"CertificatesLoader.Log.ErrorInvalid")];
			 return;
		 }

		[LogHelper log:LSTR(@"CertificatesLoader.Log.Found")];

		 CFStringRef certNameRef = NULL;
		 SecCertificateCopyCommonName(cert, &certNameRef);

		 if (!certNameRef)
		 {
			 [LogHelper log:LSTR(@"CertificatesLoader.Log.ErrorName")];
			 CFRelease(cert);
			 return;
		 }

		  NSString *certificateName = CFBridgingRelease(certNameRef);
		 [LogHelper log:LSTR(@"CertificatesLoader.Log.CertNameFrmt"), certificateName];

		 CFDataRef certSerialDataRef = SecCertificateCopySerialNumber(cert, NULL);

		 if (!certSerialDataRef)
		 {
			 [LogHelper log:LSTR(@"CertificatesLoader.Log.ErrorSerial")];
			 CFRelease(cert);
			 return;
		 }

		 if (![self certificateExistsInKeychainCerts:keychainCerts withCertSerialData:CFBridgingRelease(certSerialDataRef)])
		 {
			 [LogHelper log:LSTR(@"CertificatesLoader.Log.ErrorNotFound")];
			 CFRelease(cert);
			 return;
		 }

		 [LogHelper log:LSTR(@"CertificatesLoader.Log.OK")];
		 [avaiableCertificates addObject:certificateName];
		 CFRelease(cert);
	 }];

	if (avaiableCertificates.count == 0)
	{
		[LogHelper log:LSTR(@"CertificatesLoader.Log.ErrorNoAvailCert")];
	}

	[self finish:avaiableCertificates];
}


- (void)cancel
{
	[self finish:nil];
	[super cancel];
}


#pragma mark - Private methods

- (NSArray *)keychainCertificates
{
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{(__bridge NSString *)kSecReturnRef: (__bridge NSNumber *)kCFBooleanTrue,
																				 (__bridge NSString *)kSecMatchLimit: (__bridge NSString *)kSecMatchLimitAll,
																				 (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassCertificate}];
	CFArrayRef result = NULL;
	SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
	return CFBridgingRelease(result);
}


- (BOOL)certificateExistsInKeychainCerts:(NSArray *)keychainCerts withCertSerialData:(NSData *)certSerialData
{
	__block BOOL found = NO;

	[keychainCerts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
	{
		if (self.isCancelled)
		{
			*stop = YES;
			return;
		}

		SecCertificateRef kCert = (SecCertificateRef)CFBridgingRetain(obj);
		CFDataRef kCertSerialDataRef = SecCertificateCopySerialNumber(kCert, NULL);

		if (kCertSerialDataRef)
		{
			NSData *kCertSerialData = CFBridgingRelease(kCertSerialDataRef);

			if ([kCertSerialData isEqualToData:certSerialData])
			{
				found = YES;
				*stop = YES;
			}
		}

		CFRelease(kCert);
	}];

	return found;
}


- (void)finish:(NSArray<NSString *> *)avaiableCertificates
{
	if (!self.isCancelled && _finishBlock)
	{
		CertificatesLoaderFinishBlock finishBlock = _finishBlock;

		dispatch_async(dispatch_get_main_queue(), ^
		{
			if (!self.isCancelled)
			{
				[LogHelper log:LSTR(@"CertificatesLoader.Log.Done")];
				finishBlock(avaiableCertificates);
			}
		});
	}

	_finishBlock = nil;
}

@end
