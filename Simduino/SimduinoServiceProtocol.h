//
//  SimduinoProtocol.h
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>

// The protocol that this service will vend as its API. This header file will also need to be visible to the process hosting the service.
@protocol SimduinoServiceProtocol

// Replace the API of this protocol with an API appropriate to the service you are vending.
//- (void)upperCaseString:(NSString * _Nonnull)aString withReply:(void (^ _Nonnull)(NSString * _Nonnull))reply;
- (void)startupSimduinoWithDebug:(BOOL)debug
                       withReply:(void (^ _Nonnull)(NSString * _Nullable))ptyNameCallbackIn;
- (void)shutdownSimduino:(void (^ _Nonnull)(void))ptyClosedCallbackIn;
- (void)restartSimduino:(void (^ _Nonnull)(void))restartedCallbackIn;
    
@end

@protocol SimduinoHostProtocol<NSObject>

- (void)LChanged:(BOOL)newValue;

@end
