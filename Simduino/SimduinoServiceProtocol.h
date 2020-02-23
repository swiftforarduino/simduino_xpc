//
//  SimduinoProtocol.h
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SimduinoServiceProtocol

// start a simduino instance, either with a specific ELF file
// or by default if that's not specified then run a bootloader
- (void)startupSimduinoWithExecutable:(NSString * _Nullable)filename
                                debug:(BOOL)debugIn
                            withReply:(void (^ _Nonnull)(NSString * _Nullable))ptyNameCallbackIn;


- (void)shutdownSimduino:(void (^ _Nonnull)(void))ptyClosedCallbackIn;
- (void)restartSimduino:(void (^ _Nonnull)(void))restartedCallbackIn;
    
@end

@protocol SimduinoHostProtocol<NSObject>

- (void)LChanged:(BOOL)newValue;
- (void)simduinoLogMessage:(NSString * _Nonnull)message level:(NSInteger)logLevel;

@end
