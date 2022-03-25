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

// we may want to generalise this one day
static void (*global_simduino_log_hook)(avr_t * avr, const int level, char *) = 0;

#define LOG_SIZE 2000

char logBuffer[LOG_SIZE];

avr_logger_p _old_logger = 0;

static void
global_simduino_logger(
        avr_t * avr,
        const int level,
        const char * format,
        va_list ap)
{
    if (!avr || avr->log >= level) {
        vsnprintf(logBuffer, LOG_SIZE, format, ap);
        if (global_simduino_log_hook) {
            global_simduino_log_hook(avr, level, logBuffer);
        }
//        if (_old_logger) {
//            _old_logger(avr, level, format, ap);
//        }
    }
}

static void setup_global_simduino_logger(avr_t * avr, void (*hook)(avr_t * avr, const int level, char *)) {
    global_simduino_log_hook = hook;
    if (!_old_logger) {
        _old_logger = avr_global_logger_get();
    }
    avr_global_logger_set(global_simduino_logger);
}

@interface Simduino () {
    elf_firmware_t f;
    uart_pty_t uart_pty;
    avr_t * avr;
    uint8_t port_b_state;
}

@property (nonatomic) BOOL LState; // state of the simulated LED attached to pin 13
@property (atomic) void (^reloadCallback)(void);
@property NSFileHandle * tapSlaveFileHandle;
@property id dataAvailableObserver;
@property (nonatomic, readwrite) id<SimduinoHostProtocol> _Nullable simduinoHost;
@property (nonatomic, readwrite) SimduinoDebugType debug;

@end

@implementation Simduino

void pin_changed_hook(struct avr_irq_t * irq, uint32_t value, void * param)
{
    Simduino * const simduino = (__bridge Simduino * const)param;
    simduino->port_b_state = (simduino->port_b_state & ~(1 << irq->irq)) | (value << irq->irq);
    simduino.LState = (simduino->port_b_state & (1<<5)) ? YES : NO;
}

static Simduino * simduino_for_logging;
void simduino_log(avr_t * avr, const int level, char * message) {
    // we currently don't have a mechanism to tie an avr back to its Simduino
    // the S4A UI only shows one simulator
    // if anyone else is using this code and wants to fix this, please feel free to raise a PR, it would be welcome!
    [simduino_for_logging simduinoLogMessage:message level:level];
}

- (void)simduinoLogMessage:(char *)message level:(const int)logLevel {
    NSString *cookedMessage = [NSString stringWithCString:message encoding:NSASCIIStringEncoding];
    NSInteger cookedLevel = logLevel;
    if (cookedMessage) {
        [_simduinoHost simduinoLogMessage:cookedMessage level:cookedLevel];
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

- (instancetype)initWithMcu:(NSString * _Nonnull)mcu
                  frequency:(float)frequency
                   unoStyle:(BOOL)unoStyle
               simduinoHost:(id<SimduinoHostProtocol> _Nullable)simduinoHost
                      debug:(SimduinoDebugType)debug {
    self = [super init];
    if (self) {
        self.simduinoHost = simduinoHost;
        const char * mmcu = [mcu cStringUsingEncoding:NSUTF8StringEncoding];
        strcpy(f.mmcu, mmcu);
        f.frequency = frequency;

        avr = avr_make_mcu_by_name(mmcu);

        if (!avr) {
            fprintf(stderr, "Error creating the AVR core\n");
            return nil;
        }

        avr_init(avr);

        avr->log = LOG_ERROR;
        setup_global_simduino_logger(avr, simduino_log);
        simduino_for_logging = self;

        self.debug = debug;

        if (unoStyle) {
            avr_irq_register_notify(
                                    avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 5),
                                    pin_changed_hook,
                                    (__bridge void *)self);

            uart_pty_init(avr, &uart_pty);
            uart_pty_connect(&uart_pty, '0');
            char logMsg[50];
            snprintf(logMsg, 50, "Created virtual UART: %s\n", uart_pty.pty.slavename);
            simduino_log(NULL, LOG_DEBUG, logMsg);
        }
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

#define EXEC_PATH_BUFFER_SIZE 1024
- (BOOL)loadELFFile:(NSString  * _Nonnull)filename {
    char executable_path[EXEC_PATH_BUFFER_SIZE];
    strncpy(executable_path, [filename cStringUsingEncoding:NSUTF8StringEncoding], EXEC_PATH_BUFFER_SIZE);
    if (elf_read_firmware(executable_path, &f) == -1) {
        fprintf(stderr, "Unable to load firmware from file %s\n", executable_path);
        return false;
    } else {
        return true;
    }
}

- (void)reloadWithELFFile:(NSString * _Nonnull)filename {
    if (_reloadCallback) return; // no re-entrancy
    __weak Simduino * weakSim = self;
    _reloadCallback = ^{
        // cleanup old machine
        if (weakSim) {
            Simduino * strongSim = weakSim;
            [strongSim loadELFFile:filename];
            [strongSim setup];
            strongSim.restartedCallback = ^{}; // do a reboot to run the new program
            strongSim.reloadCallback = nil; // allow the simulator to continue/restart with the new
        }
    }; // as soon as the _reloadCallback is set, the simulator should go into a pause to run it
}

- (BOOL)setup {
    avr_load_firmware(avr, &f);

    if (f.flashbase) {
        printf("Attempted to load firmware at %04x\n", f.flashbase);
        avr->pc = f.flashbase;
        avr->codeend = avr->flashend;
        return true;
    } else {
        return false;
    }
}

- (void)dealloc {
    NSLog(@"ENDING SIMDUINO");
    [self closeSimulatedUARTTap];
}

- (void)dataAvailableFromTapSlaveTTY {
    [_simduinoHost tapSlaveDataReceived:[self.tapSlaveFileHandle availableData]];
}

// open the slave side of the tap pty/tty pair and listen for data
// send read data back using the xpc socket and allow writing via an xpc method too
- (BOOL)openSimulatedUARTTap {
    if (self.tapSlaveFileHandle) {
        // already open
        NSLog(@"file handle already open: %@",self.tapSlaveFileHandle);
        return NO;
    }

    self.tapSlaveFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:[NSString stringWithFormat:@"%s",uart_pty.pty.slavename]];
    if (self.tapSlaveFileHandle) {
        __weak Simduino * _weakSelf = self;

        self.dataAvailableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification
                                                          object:self.tapSlaveFileHandle
                                                           queue:NSOperationQueue.mainQueue
                                                      usingBlock:^(NSNotification * _Nonnull note) {

            [_weakSelf dataAvailableFromTapSlaveTTY];
            [_weakSelf.tapSlaveFileHandle waitForDataInBackgroundAndNotify];
        }];


        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tapSlaveFileHandle waitForDataInBackgroundAndNotify];
        });

        return YES;
    } else {
        perror("failed to open my slave");
        return NO;
    }
}

- (BOOL)closeSimulatedUARTTap {
    if (self.tapSlaveFileHandle) {
        if (self.dataAvailableObserver) {
            [[NSNotificationCenter defaultCenter] removeObserver:self.dataAvailableObserver];
        }

        NSError * closeError = nil;
        if (@available(macOS 10.15, *)) {
            if ([self.tapSlaveFileHandle closeAndReturnError:&closeError]) {
                self.tapSlaveFileHandle = nil;
                return YES;
            } else {
                NSLog(@"problem closing file handle: %@",[closeError localizedDescription]);
                self.tapSlaveFileHandle = nil;
                return NO;
            }
        } else {
            [self.tapSlaveFileHandle closeFile];
            self.tapSlaveFileHandle = nil;
            return YES;
        }
    } else {
        self.tapSlaveFileHandle = nil;
        return NO;
    }
}

- (BOOL)writeTapSlaveData:(NSData * _Nonnull)data {
    NSError * writeError = nil;
    if (@available(macOS 10.15, *)) {
        return [self.tapSlaveFileHandle writeData:data error:&writeError];
    } else {
        return NO;
    }
}

- (void)setDebug:(SimduinoDebugType)debugIn {
    if (_debug != debugIn) {
        _debug = debugIn;

        if (debugIn) {
            avr->gdb_port = SIMDUINO_GDB_PORT;
            avr_gdb_init(avr);
        } else {
            avr_deinit_gdb(avr);
            avr->gdb_port = 0;
        }
    }
}

- (void)main {
    int state = cpu_Running; // default for while loop

    if (_startCallbackIn) {
        _startCallbackIn();
        _startCallbackIn = nil;
    }

    if (self.debug == debugAndWait) {
        avr->state = cpu_Stopped;
        state = cpu_Stopped;
    }

    self.inMainLoop = YES;
    while (!self.cancelled && state != cpu_Done && state != cpu_Crashed) {
        if (_restartedCallback) {
            // restart requested
            NSLog(@"resetting avr...");
            avr_reset(avr);
            _restartedCallback();
            _restartedCallback = nil;

            // make sure gdb is reinitialised after restart
            if (self.debug == debugAndWait) {
                avr->state = cpu_Stopped;
                state = cpu_Stopped;
            }
        }

        state = avr_run(avr); // might be a bit heavy on the CPU

        if (_reloadCallback) {
            // hook to allow the engine to pause and reload
            _reloadCallback();
        }
    }

    self.inMainLoop = NO;

    // prevent rare race condition where restarted callback is set outside the main loop
    if (_restartedCallback) {
        _restartedCallback();
        _restartedCallback = nil;
    }

    uart_pty_stop(&uart_pty);
    avr_terminate(avr);

    if (_ptyClosedCallback) {
        _ptyClosedCallback();
        _ptyClosedCallback = nil;
    }

    [_simduinoHost simduinoDidStop];
}

@end
