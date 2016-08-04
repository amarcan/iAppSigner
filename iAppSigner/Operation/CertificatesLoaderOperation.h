//
//  CertificatesLoaderOperation.h
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void (^CertificatesLoaderFinishBlock)(NSArray<NSString *> *avaiableCertificates);

@interface CertificatesLoaderOperation : NSOperation

+ (instancetype)operationWithProvProfileDict:(NSDictionary *)profileDict
							  andFinishBlock:(CertificatesLoaderFinishBlock)finishBlock;

@end
