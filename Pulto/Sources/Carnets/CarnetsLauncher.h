//
//  CarnetsLauncher.h
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Minimal Obj-C bridge we call from Swift.
/// You will link it with CPython + your fork's bootstrap.
@interface CarnetsLauncher : NSObject

/// Starts the embedded Jupyter server in-process on a background thread.
/// Returns YES on success; fills `error` on failure.
+ (BOOL)startAtPath:(NSString *)root port:(NSInteger)port error:(NSError **)error;

/// Requests a graceful stop if possible.
+ (void)stop;

@end

NS_ASSUME_NONNULL_END