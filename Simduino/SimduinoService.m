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
    BOOL _startingOrStopping;
}

@end

@implementation SimduinoService

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

- (void)openSimulatedUARTWithReply:(void (^ _Nonnull)(NSFileHandle* _Nullable slaveFileHandle))openCallbackIn {
    openCallbackIn(nil);
    printf("*** temporarily disable all serial access\n");
//    dispatch_async(dispatch_get_main_queue(), ^{
//        openCallbackIn([self->_currentSimduino openSimulatedUART]);
//    });
}

- (void)closeSimulatedUARTWithReply:(void (^ _Nonnull)(BOOL success))closeCallbackIn {
    printf("*** temporarily disable all serial access\n");
    closeCallbackIn(true);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        closeCallbackIn([self->_currentSimduino closeSimulatedUART]);
//    });
}

// create an NSOperation to run the simulator
// should all be done in that
- (void)startupSimduinoWithExecutable:(NSString * _Nullable)filename
                                debug:(SimduinoDebugType)debugIn
                            withReply:(void (^ _Nonnull)(void))startCallbackIn {

    if ([self isSimduinoRunning]) {
        // already running, return immediately
        startCallbackIn();
        printf("simduino already running... short circuit\n");
        return;
    }

    _startingOrStopping = YES;

    printf("calling simduino start %p, _startingOrStopping: %d\n",self,_startingOrStopping);
    Simduino *simduino = [Simduino new];
    simduino.debug = debugIn;
    simduino.simduinoHost = self.simduinoHost;
    simduino.startCallbackIn = startCallbackIn;

    if (filename) {
        [simduino loadELFFile:filename];
    } else {
        [simduino loadBootloader];
    }

    [simduino setup];

    _currentSimduino = simduino;

    [operationQueueForScheduling addOperation:simduino];

    _startingOrStopping = NO;
}

- (void)simduinoIsRunningWithReply:(void (^ _Nonnull)(BOOL running))isRunningCallbackIn {
    isRunningCallbackIn([self isSimduinoRunning]);
}

- (BOOL)isSimduinoRunning {
    return (BOOL)_currentSimduino || _startingOrStopping;
}

- (void)shutdownSimduino:(void (^)(void))ptyClosedCallbackIn {
    _startingOrStopping = YES;
    printf("calling simduino stop\n"); /// note: printf works: NSLOG DOES NOT WORK!!!
    _currentSimduino.ptyClosedCallback = ptyClosedCallbackIn;
    [_currentSimduino cancel];
    _currentSimduino = nil;
    _startingOrStopping = NO;
}

- (void)restartSimduino:(void (^)(void))restartedCallbackIn {
    if (_currentSimduino.inMainLoop) {
        printf("calling simduino reset\n");
        _currentSimduino.restartedCallback = restartedCallbackIn;
    } else {
        printf("simduino not running, currently starting or stopping, cannot reset\n");
        restartedCallbackIn();
    }
}

- (void)defineContainerDirectory:(NSString*)containerDirectory
                       withReply:(void (^ _Nonnull)(void))callback; {
    containerLocation = [containerDirectory cStringUsingEncoding:NSUTF8StringEncoding];
    callback();
}

@end
