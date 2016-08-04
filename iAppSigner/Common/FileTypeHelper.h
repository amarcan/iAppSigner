//
//  FileTypeHelper.h
//  iAppSigner
//
//  Created by Alan Marcan on 28.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface FileTypeHelper : NSObject

+ (BOOL)isExtensionProvProfile:(NSString *)extension;
+ (BOOL)isExtensionIPAFile:(NSString *)extension;

@end
