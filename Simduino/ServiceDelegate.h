//
//  ServiceDelegate.h
//  Simduino
//
//  Created by Carl Peto on 20/02/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate> {
    NSOperationQueue * simduinoQueue; // will only run one simduino at a time, each is long running
}
@end
