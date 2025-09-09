//
//  CarnetsBootstrap.h
//  Pulto3
//
//  Created by Joshua Herman on 9/9/25.
//  Copyright © 2025 Apple. All rights reserved.
//


// Pulto/Sources/Carnets/CarnetsBootstrap.h
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// One-time initialization for embedded Jupyter (env/CPython).
BOOL CarnetsBootstrapInitialize(NSError **error);

/// Start Jupyter Notebook server bound to 127.0.0.1:port using `root` as HOME.
/// Should return quickly (server runs on a background thread).
BOOL CarnetsBootstrapStartServer(NSString *root, NSInteger port, NSError **error);

/// Request a graceful shutdown of the server.
void CarnetsBootstrapStopServer(void);

#ifdef __cplusplus
}
#endif
