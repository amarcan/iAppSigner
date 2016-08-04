//
//  ProvProfileParserOperation.h
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void (^ProvProfileParserFinishBlock)(NSDictionary *provProfileDict);

@interface ProvProfileParserOperation : NSOperation

+ (instancetype)operationWithProvProfilePath:(NSString *)provProfilePath
							  andFinishBlock:(ProvProfileParserFinishBlock)finishBlock;

@end
