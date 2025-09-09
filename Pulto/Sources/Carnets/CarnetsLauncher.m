//
//  CarnetsLauncher.m
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


// CarnetsLauncher.m
#import "CarnetsLauncher.h"
#import <Foundation/Foundation.h>
#import "CarnetsLauncher.h"
#import "CarnetsBootstrap.h"   // <-- now exists in your app sources


static volatile BOOL sIsRunning = NO;
static int sPort = 8888;

@implementation CarnetsLauncher

+ (BOOL)startAtPath:(NSString *)root port:(NSInteger)port error:(NSError **)error {
    if (sIsRunning) { return YES; }
    sPort = (int)port;

    // 1) Initialize your fork’s runtime (CPython, env, sys.path, etc.)
    NSError *initErr = nil;
    if (!CarnetsBootstrapInitialize(&initErr)) {
        if (error) { *error = initErr ?: [NSError errorWithDomain:@"CarnetsLauncher"
                                                             code:-1
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Bootstrap initialize failed"}]; }
        return NO;
    }

    // 2) Start the server (non-blocking preferred; if it blocks, you can move this call to a pthread)
    NSError *startErr = nil;
    BOOL ok = CarnetsBootstrapStartServer(root, port, &startErr);
    if (!ok) {
        if (error) { *error = startErr ?: [NSError errorWithDomain:@"CarnetsLauncher"
                                                              code:-2
                                                          userInfo:@{NSLocalizedDescriptionKey: @"Failed to start Jupyter server"}]; }
        return NO;
    }

    sIsRunning = YES;
    return YES;
}

+ (void)stop {
    if (!sIsRunning) return;
    // 3) Ask the fork to stop the server gracefully
    CarnetsBootstrapStopServer();
    sIsRunning = NO;
}

@end
