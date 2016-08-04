//
//  ProcessAndSignOperation.h
//  iAppSigner
//
//  Created by Alan Marcan on 27.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void (^ProcessAndSignFinishBlock)(BOOL success, NSString *tmpIPAFilePath);

@interface ProcessAndSignOperation : NSOperation

+ (instancetype)operationWithCertificate:(NSString *)certName
						 provProfilePath:(NSString *)provProfilePath
						 provProfileDict:(NSDictionary *)provProfileDict
							 ipaFilePath:(NSString *)ipaFilePath
					  updateEntitlements:(BOOL)updateEntitlements
						  andFinishBlock:(ProcessAndSignFinishBlock)finishBlock;

@end
