//
//  SimduinoService.m
//  Simduino
//
//  Created by Carl Peto on 19/02/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import "SimduinoService.h"
#import "Simduino.h"
#import "uart_pty.h"

@interface SimduinoService () {
    __weak NSOperationQueue * operationQueueForScheduling;
    __weak Simduino * _currentSimduino;
}

@end

@implementation SimduinoService

- (instancetype)init {
    NSAssert(false, @"do not use this");
    return [self initWithOperationQueue:nil];
}

- (instancetype)initWithOperationQueue:(NSOperationQueue*)queue {
    self = [super init];
    if (self) {
        operationQueueForScheduling = queue;
    }
    return self;
}

- (void)loadNewExecutable:(NSString * _Nullable)filename
                withReply:(void (^ _Nonnull)(BOOL))callback {
    if (!_currentSimduino) {
        callback(NO);
    } else {
        [_currentSimduino reloadWithELFFile:filename];
        callback(YES);
    }
}

- (void)openSimulatedUARTWithReply:(void (^ _Nonnull)(BOOL success))openCallbackIn {
    openCallbackIn([_currentSimduino openSimulatedUARTTap]);
}

- (void)closeSimulatedUARTWithReply:(void (^ _Nonnull)(BOOL success))closeCallbackIn {
    closeCallbackIn([_currentSimduino closeSimulatedUARTTap]);
}

- (void)writeTapSlaveData:(NSData * _Nonnull)data withReply:(void (^ _Nonnull)(BOOL success))callback {
    callback([_currentSimduino writeTapSlaveData:data]);
}

// create an NSOperation to run the simulator
// should all be done in that
- (void)startupSimduinoWithExecutable:(NSString * _Nullable)filename
                                  mcu:(NSString * _Nullable)mcu
                         cpuFrequency:(float)cpuFrequency
                             unoStyle:(BOOL)unoStyle
                                debug:(SimduinoDebugType)debugIn
                            withReply:(void (^ _Nonnull)(void))startCallbackIn {

    NSLog(@"creating simduino");
    Simduino *simduino = [[Simduino alloc] initWithMcu:mcu
                                             frequency:cpuFrequency
                                              unoStyle:unoStyle
                                          simduinoHost:self.simduinoHost
                                                 debug:debugIn];

    simduino.startCallbackIn = startCallbackIn;

    if (filename) {
        [simduino loadELFFile:filename];
    } else {
        [simduino loadBootloader];
    }

    [simduino setup];

    _currentSimduino = simduino;

    [operationQueueForScheduling addOperation:simduino];
}

- (void)shutdownSimduino:(void (^)(void))ptyClosedCallbackIn {
    NSLog(@"calling simduino stop");
    _currentSimduino.ptyClosedCallback = ptyClosedCallbackIn;
    [_currentSimduino cancel];
}

- (void)restartSimduino:(void (^)(void))restartedCallbackIn {
    if (_currentSimduino.inMainLoop) {
        NSLog(@"calling simduino reset");
        _currentSimduino.restartedCallback = restartedCallbackIn;
    } else {
        NSLog(@"simduino not running, currently starting or stopping, cannot reset");
        restartedCallbackIn();
    }
}
- (void)defineContainerDirectory:(NSString*)containerDirectory
                       withReply:(void (^ _Nonnull)(void))callback; {
    containerLocation = [containerDirectory cStringUsingEncoding:NSUTF8StringEncoding];
    callback();
}
@end
