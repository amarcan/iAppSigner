//
//  LogHelper.h
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface LogHelper : NSObject

+ (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
+ (void)clearLog;

@end
