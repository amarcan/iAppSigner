//
//  FileCopyHelper.h
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FileCopyHelper : NSOperation

+ (NSString *)atomicFileCopyAtPath:(NSString *)path toPath:(NSString *)toPath error:(NSError **)error;

@end
