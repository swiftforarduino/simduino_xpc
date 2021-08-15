//
//  SimduinoProtocol.h
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>

#define SIMDUINO_GDB_PORT 7979

typedef NS_ENUM(NSUInteger, SimduinoDebugType) {
    noDebug = 0,
    debugNoWait = 1,
    debugAndWait = 2
};

@protocol SimduinoServiceProtocol

// start a simduino instance, either with a specific ELF file
// or by default if that's not specified then run a bootloader
- (void)startupSimduinoWithExecutable:(NSString * _Nullable)filename
                                debug:(SimduinoDebugType)debugIn
                            withReply:(void (^ _Nonnull)(NSString * _Nullable))ptyNameCallbackIn;

- (void)openSimulatedUARTWithReply:(void (^ _Nonnull)(BOOL success))openCallbackIn;
- (void)closeSimulatedUARTWithReply:(void (^ _Nonnull)(BOOL success))closeCallbackIn;

- (void)shutdownSimduino:(void (^ _Nonnull)(void))ptyClosedCallbackIn;
- (void)restartSimduino:(void (^ _Nonnull)(void))restartedCallbackIn;

- (void)loadNewExecutable:(NSString * _Nullable)filename
                withReply:(void (^ _Nonnull)(BOOL))callback;

- (void)defineContainerDirectory:(NSString * _Nonnull)containerDirectory
                       withReply:(void (^ _Nonnull)(void))callback;

- (void)writeTapSlaveData:(NSData * _Nonnull)data withReply:(void (^ _Nonnull)(BOOL success))callback;

@end

@protocol SimduinoHostProtocol<NSObject>

- (void)LChanged:(BOOL)newValue;
- (void)simduinoLogMessage:(NSString * _Nonnull)message level:(NSInteger)logLevel;
- (void)simduinoDidStop;
- (void)tapSlaveDataReceived:(NSData * _Nonnull)data;

@end
