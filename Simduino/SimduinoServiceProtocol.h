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

// significant change to function...
// when you start the simduino, it does NOT open the slave tty
// and it does not even tell you what device the slave tty is on
// you never know and you never need to know
// ...in order to open or close the slave tty, you call
// openSimulatedUARTWithReply and closeSimulatedUARTWithReply
// open will pass you back an NSFileHandle that you can monitor with a dispatch source
// usually attached on the main run loop/thread
// to close, simply call closeSimulatedUARTWithReply, simduino remembers the fd to close
// simduino is solely responsible for opening and closing the slave tty
// this enhances security for the whole system
// if you need to know the slave tty device name (for example to open it in minicom)
// look in the logs

// start a simduino instance, either with a specific ELF file
// or by default if that's not specified then run a bootloader
- (void)startupSimduinoWithExecutable:(NSString * _Nullable)filename
                                debug:(SimduinoDebugType)debugIn
                            withReply:(void (^ _Nonnull)(void))startCallbackIn;

- (void)openSimulatedUARTWithReply:(void (^ _Nonnull)(NSFileHandle* _Nullable slaveFileHandle))openCallbackIn;
- (void)closeSimulatedUARTWithReply:(void (^ _Nonnull)(BOOL success))closeCallbackIn;

- (void)shutdownSimduino:(void (^ _Nonnull)(void))ptyClosedCallbackIn;
- (void)restartSimduino:(void (^ _Nonnull)(void))restartedCallbackIn;

- (void)loadNewExecutable:(NSString * _Nullable)filename
                withReply:(void (^ _Nonnull)(BOOL))callback;

- (void)defineContainerDirectory:(NSString*_Nonnull)containerDirectory
                       withReply:(void (^ _Nonnull)(void))callback;

@end

@protocol SimduinoHostProtocol<NSObject>

- (void)LChanged:(BOOL)newValue;
- (void)simduinoLogMessage:(NSString * _Nonnull)message level:(NSInteger)logLevel;
- (void)simduinoSerialOutput:(NSString * _Nonnull)output;

@end
