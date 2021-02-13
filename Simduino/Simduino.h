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

@property (nonatomic) id<SimduinoHostProtocol> _Nullable simduinoHost;
@property (atomic) void (^ _Nullable startCallbackIn)(void);
@property (atomic) void (^ _Nullable ptyClosedCallback)(void);
@property (atomic) void (^ _Nullable restartedCallback)(void);
@property (atomic) SimduinoDebugType debug;
@property (atomic) SimduinoDebugType inMainLoop;

- (BOOL)loadBootloader;
- (BOOL)loadELFFile:(NSString * _Nonnull)filename;
- (BOOL)setup;
- (void)reloadWithELFFile:(NSString * _Nonnull)filename; // attempt a hot reload
- (NSFileHandle * _Nullable)openSimulatedUART;
- (BOOL)closeSimulatedUART;

@end
