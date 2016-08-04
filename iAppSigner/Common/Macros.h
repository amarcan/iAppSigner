//
//  Macros.h
//  iAppSigner
//
//  Created by Alan Marcan on 26.07.2016..
//  Copyright © 2016. Alan Marcan. All rights reserved.
//


#ifdef DEBUG
#   define ILog(fmt, ...) NSLog((fmt), ##__VA_ARGS__)
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define ILog(...)
#   define DLog(...)
#endif

#define APPDEL ((AppDelegate *)NSApp.delegate)

#define LSTR(str) NSLocalizedString(str, nil)

#define WSELF __weak typeof(self) wself = self

#define CLASS_SAFE_VALUE(val, aClass, defaultVal) (\
{ \
id safeVal = val; \
if (!!safeVal && ![safeVal isKindOfClass:aClass]) \
{ \
  safeVal = defaultVal; \
} \
safeVal; \
})
