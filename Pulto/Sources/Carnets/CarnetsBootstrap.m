//
//  CarnetsBootstrap.m
//  Pulto
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//

// Pulto/Sources/Carnets/CarnetsBootstrap.m
#import "CarnetsBootstrap.h"
#import <Foundation/Foundation.h>

#if __has_include(<Python/Python.h>)
  #import <Python/Python.h>
  #define HAVE_PY 1
#else
  #define HAVE_PY 0
#endif

static volatile BOOL sInited = NO;
static volatile BOOL sRunning = NO;
static int sPort = 8888;

BOOL CarnetsBootstrapInitialize(NSError **error) {
    if (sInited) return YES;
#if HAVE_PY
    if (!Py_IsInitialized()) {
        Py_Initialize();
        if (!Py_IsInitialized()) {
            if (error) *error = [NSError errorWithDomain:@"CarnetsBootstrap"
                                                    code:-1
                                                userInfo:@{NSLocalizedDescriptionKey:@"Failed to initialize CPython"}];
            return NO;
        }
    }
    sInited = YES;
    return YES;
#else
    if (error) *error = [NSError errorWithDomain:@"CarnetsBootstrap"
                                            code:-2
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                   @"CPython headers not found. Link Carnets CPython xcframeworks to enable embedded Python."}];
    return NO;
#endif
}

BOOL CarnetsBootstrapStartServer(NSString *root, NSInteger port, NSError **error) {
#if HAVE_PY
    if (sRunning) return YES;
    sPort = (int)port;

    // Minimal NotebookApp launcher script
    NSMutableString *script = [NSMutableString string];
    [script appendString:
     "import os\n"
     "from notebook.notebookapp import NotebookApp\n"
     "app = NotebookApp.instance()\n"
     "app.ip = '127.0.0.1'\n"];
    [script appendFormat:@"app.port = %d\n", sPort];
    [script appendString:
     "app.open_browser = False\n"
     "app.token = ''\n"
     "app.password = ''\n"
     "app.disable_check_xsrf = True\n"
     "app.allow_root = True\n"
     "app.initialize([])\n"
     "app.start()\n"];

    sRunning = YES;
    NSString *scriptCopy = [script copy];
    NSString *cwd = [root copy];

    // Run on a background queue so we don't block UI
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            chdir([cwd fileSystemRepresentation]);
            PyRun_SimpleString([scriptCopy UTF8String]); // blocks until server stops
            sRunning = NO;
        }
    });

    return YES;
#else
    if (error) *error = [NSError errorWithDomain:@"CarnetsBootstrap"
                                            code:-3
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                   @"CPython not available; cannot start Jupyter. Link python xcframeworks."}];
    return NO;
#endif
}

void CarnetsBootstrapStopServer(void) {
    if (!sRunning) return;

    // Ask the server to shut down via REST. Avoid poking Tornado from C.
    NSString *urlStr = [NSString stringWithFormat:@"http://127.0.0.1:%d/api/shutdown", sPort];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 5.0;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req] resume];
}
