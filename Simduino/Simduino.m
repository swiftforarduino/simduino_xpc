//
//  Simduino.m
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import "Simduino.h"
#include "sim_avr.h"
#include "avr_ioport.h"
#import "sim_elf.h"
#import "sim_hex.h"
#import "uart_pty.h"
#include "sim_gdb.h"

@interface Simduino () {
    elf_firmware_t f;
    uint32_t f_cpu;
    uart_pty_t uart_pty;
    avr_t * avr;
    __weak NSOperationQueue * operationQueueForScheduling;
    void (^ptyNameCallback)(NSString *);
    void (^ptyClosedCallback)(void);
    void (^restartedCallback)(void);
    uint8_t port_b_state;
}

@property (nonatomic) BOOL debug;
@property (atomic) BOOL debugChanged;
@property (nonatomic) BOOL LState; // state of the simulated LED attached to pin 13

@end

@implementation Simduino

- (void)setDebug:(BOOL)debug {
    if (_debug != debug) {
        _debug = debug;
        _debugChanged = YES;
    }
}

- (void)setLState:(BOOL)LState {
    @synchronized (self) {
        if (_LState != LState) {
            _LState = LState;
            [_simduinoHost LChanged:LState];
        }
    }
}

void pin_changed_hook(struct avr_irq_t * irq, uint32_t value, void * param)
{
    Simduino * const simduino = (__bridge Simduino * const)param;
    simduino->port_b_state = (simduino->port_b_state & ~(1 << irq->irq)) | (value << irq->irq);
    simduino.LState = (simduino->port_b_state & (1<<5)) ? YES : NO;
}

- (instancetype)initWithOperationQueue:(NSOperationQueue*)queue {
    self = [super init];
    if (self) {
        operationQueueForScheduling = queue;
        f_cpu = 16000000;
        NSString * ihexPath = [[NSBundle mainBundle] pathForResource:@"ATmegaBOOT_168_atmega328" ofType:@"ihex"];
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

        avr_irq_register_notify(
                                avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 5),
                                pin_changed_hook,
                                (__bridge void *)self);
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
        if (self.debugChanged) {
            if (self.debug) {
                avr->gdb_port = 7979;
                avr_gdb_init(avr);
            } else {
                avr_deinit_gdb(avr);
                avr->gdb_port = 0;
            }
        }

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
- (void)startupSimduinoWithDebug:(BOOL)debugIn
                       withReply:(void (^ _Nonnull)(NSString * _Nullable))ptyNameCallbackIn {
    self.debug = debugIn;

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

@end
