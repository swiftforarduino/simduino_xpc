//
//  Simduino.m
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import "Simduino.h"
#import "sim_elf.h"
#import "sim_hex.h"
#import "uart_pty.h"

@interface Simduino () {
    elf_firmware_t f;
    uint32_t f_cpu;
    uart_pty_t uart_pty;
    avr_t * avr;
    __weak NSOperationQueue * operationQueueForScheduling;
    void (^ptyNameCallback)(NSString *);
    void (^ptyClosedCallback)(void);
    void (^restartedCallback)(void);
}
@end

@implementation Simduino

- (instancetype)initWithOperationQueue:(NSOperationQueue*)queue {
    self = [super init];
    if (self) {
        operationQueueForScheduling = queue;
        f_cpu = 16000000;
        NSString * ihexPath = [[NSBundle mainBundle] pathForResource:@"ATmegaBOOT_168_atmega328" ofType:@"ihex"];
//        char boot_path[1024] = "ATmegaBOOT_168_atmega328.ihex";
        char boot_path[1024];
        strncpy(boot_path, [ihexPath cStringUsingEncoding:NSUTF8StringEncoding], 1024);
        uint32_t boot_base, boot_size;
        char * mmcu = "atmega328p";
        avr = avr_make_mcu_by_name(mmcu);
        if (!avr) {
            fprintf(stderr, "Error creating the AVR core\n");
            exit(1);
        }
        uint8_t * boot = read_ihex_file(boot_path, &boot_size, &boot_base);
        if (!boot) {
            fprintf(stderr, "Unable to load %s\n", boot_path);
            exit(1);
        }
        printf("%s booloader 0x%05x: %d bytes\n", mmcu, boot_base, boot_size);
        f.flash = boot;
        f.flashsize = boot_size;
        f.flashbase = boot_base;
        strcpy(f.mmcu, mmcu);
        f.frequency = f_cpu;
        avr_init(avr);
        avr_load_firmware(avr, &f);
        if (f.flashbase) {
            printf("Attempted to load a bootloader at %04x\n", f.flashbase);
            avr->pc = f.flashbase;
            avr->codeend = avr->flashend;
        }
    }
    return self;
}

- (void)dealloc {
    printf("ENDING SIMDUINO");
}

- (void)main {
    int state = cpu_Running; // default for while loop

    if (ptyNameCallback) {
        NSString * ptyName = [NSString stringWithCString:uart_pty.pty.slavename encoding:NSUTF8StringEncoding];
        ptyNameCallback(ptyName);
        ptyNameCallback = nil;
    }

    while (!self.cancelled && state != cpu_Done && state != cpu_Crashed) {
        if (restartedCallback) {
            // restart requested
            avr_reset(avr);
            restartedCallback();
            restartedCallback = nil;
        }
        state = avr_run(avr); // might be a bit heavy on the CPU
    }

    avr_terminate(avr);

    if (ptyClosedCallback) {
        ptyClosedCallback();
        ptyClosedCallback = nil;
    }
}

// create an NSOperation to run the simulator
// should all be done in that
- (void)startupSimduinoWithReply:(void (^)(NSString *))ptyNameCallbackIn {
    uart_pty_init(avr, &uart_pty);
    uart_pty_connect(&uart_pty, '0');

    ptyNameCallback = ptyNameCallbackIn;

    [operationQueueForScheduling addOperation:self];
}

- (void)shutdownSimduino:(void (^)(void))ptyClosedCallbackIn {
    ptyClosedCallback = ptyClosedCallbackIn;
    [self cancel];
}

- (void)restartSimduino:(void (^)(void))restartedCallbackIn {
    restartedCallback = restartedCallbackIn;
}
//
//// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
//- (void)upperCaseString:(NSString *)aString withReply:(void (^)(NSString *))reply {
//    NSString *response = [aString uppercaseString];
//    reply(response);
//}

@end
