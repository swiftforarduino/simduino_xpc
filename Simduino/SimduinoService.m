//
//  SimduinoService.m
//  Simduino
//
//  Created by Carl Peto on 19/02/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import "SimduinoService.h"
#import "Simduino.h"

@interface SimduinoService () {
    __weak NSOperationQueue * operationQueueForScheduling;
    __weak Simduino * _currentSimduino;
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

// create an NSOperation to run the simulator
// should all be done in that
- (void)startupSimduinoWithDebug:(BOOL)debugIn
                       withReply:(void (^ _Nonnull)(NSString * _Nullable))ptyNameCallbackIn {

    NSLog(@"calling simduino start");
    Simduino *simduino = [Simduino new];
    simduino.debug = debugIn;
    simduino.simduinoHost = self.simduinoHost;
    simduino.ptyNameCallback = ptyNameCallbackIn;

    _currentSimduino = simduino;

    [operationQueueForScheduling addOperation:simduino];
}

- (void)shutdownSimduino:(void (^)(void))ptyClosedCallbackIn {
    NSLog(@"calling simduino stop");
    _currentSimduino.ptyClosedCallback = ptyClosedCallbackIn;
    [_currentSimduino cancel];
}

- (void)restartSimduino:(void (^)(void))restartedCallbackIn {
    NSLog(@"calling simduino reset");
    _currentSimduino.restartedCallback = restartedCallbackIn;
}
@end