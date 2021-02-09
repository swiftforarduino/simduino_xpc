//
//  Simduino.h
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SimduinoServiceProtocol.h"

@interface Simduino : NSOperation

@property (nonatomic) id<SimduinoHostProtocol> simduinoHost;
@property (atomic) void (^ptyNameCallback)(NSString *);
@property (atomic) void (^ptyClosedCallback)(void);
@property (atomic) void (^restartedCallback)(void);
@property (atomic) SimduinoDebugType debug;
@property (atomic) SimduinoDebugType inMainLoop;

- (BOOL)loadBootloader;
- (BOOL)loadELFFile:(NSString*)filename;
- (BOOL)setup;
- (void)reloadWithELFFile:(NSString*)filename; // attempt a hot reload
- (NSFileHandle*)openSimulatedUART;
- (BOOL)closeSimulatedUART;

@end
