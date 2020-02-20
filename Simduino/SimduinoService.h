//
//  SimduinoService.h
//  Simduino
//
//  Created by Carl Peto on 19/02/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SimduinoServiceProtocol.h"

@interface SimduinoService : NSObject <SimduinoServiceProtocol>

- (instancetype)initWithOperationQueue:(NSOperationQueue*)queue NS_DESIGNATED_INITIALIZER;

@property id<SimduinoHostProtocol> simduinoHost;

@end
