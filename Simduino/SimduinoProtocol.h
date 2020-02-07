//
//  SimduinoProtocol.h
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>

// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
@protocol SimduinoProtocol

// Replace the API of this protocol with an API appropriate to the service you are vending.
//- (void)upperCaseString:(NSString * _Nonnull)aString withReply:(void (^ _Nonnull)(NSString * _Nonnull))reply;
- (void)startupSimduinoWithReply:(void (^ _Nonnull)(NSString * _Nullable))ptyNameCallbackIn;
- (void)shutdownSimduino:(void (^ _Nonnull)(void))ptyClosedCallbackIn;
- (void)restartSimduino:(void (^ _Nonnull)(void))restartedCallbackIn;
    
@end

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     _connectionToService = [[NSXPCConnection alloc] initWithServiceName:@"com.petosoft.Simduino"];
     _connectionToService.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SimduinoProtocol)];
     [_connectionToService resume];

Once you have a connection to the service, you can use it like this:

     [[_connectionToService remoteObjectProxy] upperCaseString:@"hello" withReply:^(NSString *aString) {
         // We have received a response. Update our text field, but do it on the main thread.
         NSLog(@"Result string was: %@", aString);
     }];

 And, when you are finished with the service, clean up the connection like this:

     [_connectionToService invalidate];
*/
