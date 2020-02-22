//
//  Simduino.m
//  Simduino
//
//  Created by Carl Peto on 31/01/2020.
//  Copyright © 2020 Carl Peto. All rights reserved.
//

#import "Simduino.h"
#import "SimduinoServiceProtocol.h"

#include "sim_avr.h"
#include "avr_ioport.h"
#import "sim_elf.h"
#import "sim_hex.h"
#import "uart_pty.h"
#include "sim_gdb.h"

@interface Simduino () {
    elf_firmware_t f;
    uart_pty_t uart_pty;
    avr_t * avr;
    uint8_t port_b_state;
}

@property (nonatomic) BOOL LState; // state of the simulated LED attached to pin 13

@end

@implementation Simduino

void pin_changed_hook(struct avr_irq_t * irq, uint32_t value, void * param)
{
    Simduino * const simduino = (__bridge Simduino * const)param;
    simduino->port_b_state = (simduino->port_b_state & ~(1 << irq->irq)) | (value << irq->irq);
    simduino.LState = (simduino->port_b_state & (1<<5)) ? YES : NO;
}

- (void)setLState:(BOOL)LState {
    @synchronized (self) {
        if (_LState != LState) {
            _LState = LState;
            [_simduinoHost LChanged:LState];
        }
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        char * mmcu = "atmega328p";
        strcpy(f.mmcu, mmcu);
        f.frequency = 16000000;

        avr = avr_make_mcu_by_name(mmcu);

        if (!avr) {
            fprintf(stderr, "Error creating the AVR core\n");
            return nil;
        }

        avr_init(avr);

        avr_irq_register_notify(
                                avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 5),
                                pin_changed_hook,
                                (__bridge void *)self);

        uart_pty_init(avr, &uart_pty);
        uart_pty_connect(&uart_pty, '0');
    }

    return self;
}

- (BOOL)loadBootloader {
    NSString * ihexPath = [[NSBundle mainBundle] pathForResource:@"ATmegaBOOT_168_atmega328" ofType:@"ihex"];
    char boot_path[1024];
    strncpy(boot_path, [ihexPath cStringUsingEncoding:NSUTF8StringEncoding], 1024);
    uint32_t boot_base, boot_size;
    uint8_t * boot = read_ihex_file(boot_path, &boot_size, &boot_base);

    if (!boot) {
        fprintf(stderr, "Unable to load %s\n", boot_path);
        return false;
    }

    f.flash = boot;
    f.flashsize = boot_size;
    f.flashbase = boot_base;

    return true;
}

- (BOOL)loadELFFile:(NSString*)filename {
    char executable_path[1024];
    strncpy(executable_path, [filename cStringUsingEncoding:NSUTF8StringEncoding], 1024);
    if (elf_read_firmware(executable_path, &f) == -1) {
        fprintf(stderr, "Unable to load firmware from file %s\n", executable_path);
        return false;
    } else {
        return true;
    }
}

- (BOOL)setup {
    avr_load_firmware(avr, &f);

    if (f.flashbase) {
        printf("Attempted to load a bootloader at %04x\n", f.flashbase);
        avr->pc = f.flashbase;
        avr->codeend = avr->flashend;
        return true;
    } else {
        return false;
    }
}

- (void)dealloc {
    printf("ENDING SIMDUINO");
}

- (void)main {
    int state = cpu_Running; // default for while loop

    if (_ptyNameCallback) {
        NSString * ptyName = [NSString stringWithCString:uart_pty.pty.slavename encoding:NSUTF8StringEncoding];
        _ptyNameCallback(ptyName);
        _ptyNameCallback = nil;
    }

    if (self.debug) {
        avr->gdb_port = 7979;
        avr_gdb_init(avr);
    } else {
        avr_deinit_gdb(avr);
        avr->gdb_port = 0;
    }

    while (!self.cancelled && state != cpu_Done && state != cpu_Crashed) {
        if (_restartedCallback) {
            // restart requested
            NSLog(@"resetting avr...");
            avr_reset(avr);
            _restartedCallback();
            _restartedCallback = nil;
        }

        state = avr_run(avr); // might be a bit heavy on the CPU
    }

    uart_pty_stop(&uart_pty);
    avr_terminate(avr);

    if (_ptyClosedCallback) {
        _ptyClosedCallback();
        _ptyClosedCallback = nil;
    }
}

@end
