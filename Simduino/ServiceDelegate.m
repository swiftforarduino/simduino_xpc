//
//  ServiceDelegate.m
//  Simduino
//
//  Created by Carl Peto on 20/02/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import "ServiceDelegate.h"
#import "SimduinoService.h"

@implementation ServiceDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        simduinoQueue = [NSOperationQueue new];
        simduinoQueue.name = @"Simduino Queue";
        simduinoQueue.maxConcurrentOperationCount = 1; // single thread/simduino at a time
    }
    return self;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.

    // Configure the connection.
    // First, set the interface that the exported object implements.
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SimduinoServiceProtocol)];

    // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
    SimduinoService *exportedObject = [[SimduinoService alloc] initWithOperationQueue:simduinoQueue];
    newConnection.exportedObject = exportedObject;

    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SimduinoHostProtocol)];
    id<SimduinoHostProtocol> host = [newConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"Failed to get host protocol: %@", [error localizedDescription]);
    }];

    if ([host conformsToProtocol:@protocol(SimduinoHostProtocol)] && [host respondsToSelector:@selector(LChanged:)]) {
        exportedObject.simduinoHost = host;
    } else {
        NSLog(@"host does not conform to SimduinoHostProtocol");
    }

    // Resuming the connection allows the system to deliver more incoming messages.
    [newConnection resume];

    // Returning YES from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call -invalidate on the connection and return NO.
    return YES;
}

@end
