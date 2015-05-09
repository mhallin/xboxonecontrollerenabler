//
//  GAXboxControllerViewController.m
//  Xbox One Controller Enabler
//
//  Created by Magnus Hallin on 2015-05-08.
//  Copyright (c) 2015 Guilherme Araújo. All rights reserved.
//

#import "GAXboxControllerViewController.h"

#import <VHID/VHIDDevice.h>
#import <WirtualJoy/WJoyDevice.h>

#import "GAXboxController.h"

typedef enum {
  Disconnected,
  Ready
} StatusID;

@interface GAXboxControllerViewController () <GAXboxControllerDelegate, VHIDDeviceDelegate>

@end

@implementation GAXboxControllerViewController {
  IBOutlet NSMatrix *_radioMatrix;

  IBOutlet NSButtonCell *_radioUp;
  IBOutlet NSButtonCell *_radioDown;
  IBOutlet NSButtonCell *_radioRight;
  IBOutlet NSButtonCell *_radioLeft;
  IBOutlet NSButtonCell *_radioA;
  IBOutlet NSButtonCell *_radioB;
  IBOutlet NSButtonCell *_radioX;
  IBOutlet NSButtonCell *_radioY;
  IBOutlet NSButtonCell *_radioLeftBumper;
  IBOutlet NSButtonCell *_radioRightBumper;
  IBOutlet NSButtonCell *_radioLeftAnalogButton;
  IBOutlet NSButtonCell *_radioRightAnalogButton;
  IBOutlet NSButtonCell *_radioView;
  IBOutlet NSButtonCell *_radioMenu;

  IBOutlet NSProgressIndicator *_progressLeftTrigger;
  IBOutlet NSProgressIndicator *_progressRightTrigger;
  IBOutlet NSProgressIndicator *_progressLeftAnalogX;
  IBOutlet NSProgressIndicator *_progressLeftAnalogY;
  IBOutlet NSProgressIndicator *_progressRightAnalogX;
  IBOutlet NSProgressIndicator *_progressRightAnalogY;

  IBOutlet NSButton *_connectButton;
  IBOutlet NSButton *_calibrationButton;
  IBOutlet NSButton *_resetButton;
  IBOutlet NSSegmentedControl *_triggerButton;

  IBOutlet NSTextField *_statusLabel;

  GAXboxController *_controller;
  VHIDDevice *_vhid;
  WJoyDevice *_virtualDevice;

  BOOL _isCalibrating;
  StatusID _statusID;

  NSOperationQueue *_queue;
  int _controllerIndex;
}

- (instancetype)initWithControllerIndex:(int)index queue:(NSOperationQueue *)queue {
  self = [super initWithNibName:@"GAXboxControllerViewController" bundle:[NSBundle mainBundle]];
  if (self) {
    _controllerIndex = index;
    _queue = queue;
  }

  return self;
}

#pragma mark - Calibration

- (NSDictionary *)calibrationData {
  NSString *key = [NSString stringWithFormat:@"controller_%@", _controller.usbSerialNumber];
  return [[NSUserDefaults standardUserDefaults] dictionaryForKey:key];
}

- (void)saveCalibrationData:(NSDictionary *)calibrationData {
  NSString *key = [NSString stringWithFormat:@"controller_%@", _controller.usbSerialNumber];
  [[NSUserDefaults standardUserDefaults] setObject:calibrationData forKey:key];
}

- (void)removeCalibrationData {
  NSString *key = [NSString stringWithFormat:@"controller_%@", _controller.usbSerialNumber];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

- (void)calibrate {
  float minLX = 0, minLY = 0, minRX = 0, minRY = 0,
  maxLX = 0, maxLY = 0, maxRX = 0, maxRY = 0;

  while (_isCalibrating) {
    if (_controller.leftAnalogX < minLX)
      minLX = _controller.leftAnalogX;

    if (_controller.leftAnalogY < minLY)
      minLY = _controller.leftAnalogY;

    if (_controller.rightAnalogX < minRX)
      minRX = _controller.rightAnalogX;

    if (_controller.rightAnalogY < minRY)
      minRY = _controller.rightAnalogY;


    if (_controller.leftAnalogX > maxLX)
      maxLX = _controller.leftAnalogX;

    if (_controller.leftAnalogY > maxLY)
      maxLY = _controller.leftAnalogY;

    if (_controller.rightAnalogX > maxRX)
      maxRX = _controller.rightAnalogX;

    if (_controller.rightAnalogY > maxRY)
      maxRY = _controller.rightAnalogY;
  }

  [_controller setLeftAnalogXOffset:(maxLX + minLX) / 2];
  [_controller setLeftAnalogYOffset:(maxLY + minLY) / 2];
  [_controller setRightAnalogXOffset:(maxRX + minRX) / 2];
  [_controller setRightAnalogYOffset:(maxRY + minRY) / 2];

  [_statusLabel setStringValue:@"Calibration completed."];
  [self executeBlock:^{
    [self setStatus];
  } after:1.5];

  [_calibrationButton setTitle:@"Calibrate"];
  [_calibrationButton setEnabled:YES];
  [_resetButton setEnabled:YES];

  NSDictionary *calibrationData = @{
                                    @"Offset_LX": @((maxLX + minLX) / 2),
                                    @"Offset_LY": @((maxLY + minLY) / 2),
                                    @"Offset_RX": @((maxRX + minRX) / 2),
                                    @"Offset_RY": @((maxRY + minRY) / 2),
                                    };
  [self saveCalibrationData:calibrationData];
}

#pragma mark - VHID Methods

- (void)updateVHID:(GAXboxController *)controller {
  [_vhid setButton:0 pressed:[controller A]];
  [_vhid setButton:1 pressed:[controller B]];
  [_vhid setButton:2 pressed:[controller X]];
  [_vhid setButton:3 pressed:[controller Y]];

  [_vhid setButton:4 pressed:[controller leftBumper]];
  [_vhid setButton:5 pressed:[controller rightBumper]];

  if ([_controller analogTriggers]) {
    [_vhid setButton:6 pressed:NO];
    [_vhid setButton:7 pressed:NO];
  } else {
    [_vhid setButton:6 pressed:[controller leftTrigger]];
    [_vhid setButton:7 pressed:[controller rightTrigger]];
  }

  [_vhid setButton:8 pressed:[controller view]];
  [_vhid setButton:9 pressed:[controller menu]];

  [_vhid setButton:10 pressed:[controller leftAnalogButton]];
  [_vhid setButton:11 pressed:[controller rightAnalogButton]];

  [_vhid setButton:12 pressed:[controller DPadUp]];
  [_vhid setButton:13 pressed:[controller DPadDown]];
  [_vhid setButton:14 pressed:[controller DPadLeft]];
  [_vhid setButton:15 pressed:[controller DPadRight]];

  [_vhid setButton:16 pressed:[controller xboxButton]];

  NSPoint point = NSZeroPoint;
  point.x = [controller leftAnalogX];
  point.y = [controller leftAnalogY];
  [_vhid setPointer:0 position:point];

  point.x = [controller rightAnalogX];
  point.y = [controller rightAnalogY];
  [_vhid setPointer:1 position:point];

  if ([_controller analogTriggers]) {
    point.x = [controller leftTrigger];
    point.y = [controller rightTrigger];
    [_vhid setPointer:2 position:point];
  } else {
    [_vhid setPointer:2 position:NSZeroPoint];
  }
}

#pragma mark - VHID Delegate Method

- (void)VHIDDevice:(VHIDDevice *)device stateChanged:(NSData *)state {
  [_virtualDevice updateHIDState:state];
}

#pragma mark - UI Management

- (void)cleanUI {
  [_radioMatrix deselectAllCells];
  [_radioMatrix setEnabled:NO];
  [_progressRightAnalogX setDoubleValue:-1];
  [_progressRightAnalogY setDoubleValue:-1];
  [_progressLeftAnalogX  setDoubleValue:-1];
  [_progressLeftAnalogY  setDoubleValue:-1];
  [_progressRightTrigger setDoubleValue:0];
  [_progressLeftTrigger  setDoubleValue:0];
}

- (void)updateUI:(GAXboxController *)controller {
  [_radioUp    setIntegerValue:[controller DPadUp]];
  [_radioDown  setIntegerValue:[controller DPadDown]];
  [_radioLeft  setIntegerValue:[controller DPadLeft]];
  [_radioRight setIntegerValue:[controller DPadRight]];

  [_radioA setIntegerValue:[controller A]];
  [_radioB setIntegerValue:[controller B]];
  [_radioX setIntegerValue:[controller X]];
  [_radioY setIntegerValue:[controller Y]];

  [_radioLeftBumper  setIntegerValue:[controller leftBumper]];
  [_radioRightBumper setIntegerValue:[controller rightBumper]];

  [_radioLeftAnalogButton  setIntegerValue:[controller leftAnalogButton]];
  [_radioRightAnalogButton setIntegerValue:[controller rightAnalogButton]];

  [_radioView setIntegerValue:[controller view]];
  [_radioMenu setIntegerValue:[controller menu]];

  [_progressLeftAnalogX  setDoubleValue:[controller leftAnalogX]];
  [_progressLeftAnalogY  setDoubleValue:[controller leftAnalogY]];
  [_progressRightAnalogX setDoubleValue:[controller rightAnalogX]];
  [_progressRightAnalogY setDoubleValue:[controller rightAnalogY]];
  [_progressRightTrigger setDoubleValue:[controller rightTrigger]];
  [_progressLeftTrigger  setDoubleValue:[controller leftTrigger]];
}

- (void)setStatus {
  NSString *status;

  switch (_statusID) {
    case Disconnected:
      status = @"Controller disconnected.";
      break;

    case Ready:
      status = @"Ready to use.";
      break;
  }

  [_statusLabel setStringValue:status];
}

#pragma mark - IB Actions

- (IBAction)toggleConnection:(id)sender {
  if (!_controller) {
    _controller = [[GAXboxController alloc] initWithControllerIndex:_controllerIndex queue:_queue];
    _controller.delegate = self;
    _controller.analogTriggers = _triggerButton.selectedSegment == 0;
  }

  if (_controller.isConnected) {
    [_controller disconnect];
  }
  else {
    [_controller connect];

    NSDictionary *calibrationData = self.calibrationData;
    if (calibrationData) {
      _controller.leftAnalogXOffset = [calibrationData[@"Offset_LX"] floatValue];
      _controller.leftAnalogYOffset = [calibrationData[@"Offset_LY"] floatValue];
      _controller.rightAnalogXOffset = [calibrationData[@"Offset_RX"] floatValue];
      _controller.rightAnalogYOffset = [calibrationData[@"Offset_RY"] floatValue];
    }
  }
}

- (IBAction)startCalibration:(id)sender {
  [_calibrationButton setTitle:@"Calibrating"];
  [_calibrationButton setEnabled:NO];
  [_resetButton setEnabled:NO];

  [self resetCalibration:nil];

  [_statusLabel setStringValue:@"Move both analog sticks in circles. Then release them and press any button."];

  _isCalibrating = YES;
  [self performSelectorInBackground:@selector(calibrate) withObject:nil];
}

- (IBAction)triggerMode:(id)sender {
  _controller.analogTriggers = _triggerButton.selectedSegment == 0;
}

- (IBAction)resetCalibration:(id)sender {
  _controller.leftAnalogXOffset = 0;
  _controller.leftAnalogYOffset = 0;
  _controller.rightAnalogXOffset = 0;
  _controller.rightAnalogYOffset = 0;

  [self removeCalibrationData];

  if (sender) {
    [_statusLabel setStringValue:@"Calibration reset."];
    [self executeBlock:^{
      [self setStatus];
    } after:1.5];
  }
}

#pragma mark - Calibration

#pragma mark - Xbox Controller Delegate

- (void)controllerDidConnect:(GAXboxController *)controller {
  [WJoyDevice prepare];
  [_triggerButton setEnabled:YES];
  [_controller startPolling];
  [_connectButton setTitle:@"Disconnect"];
  _vhid = [[VHIDDevice alloc] initWithType:VHIDDeviceTypeJoystick pointerCount:3 buttonCount:17 isRelative:NO];

  NSDictionary *properties = @{WJoyDeviceProductStringKey : @"Xbox One Controller"};
  //                               WJoyDeviceProductIDKey : @0x02d1,
  //                               WJoyDeviceVendorIDKey : @0x045e};
  _virtualDevice = [[WJoyDevice alloc] initWithHIDDescriptor:[_vhid descriptor] properties:properties];

  [_vhid setDelegate:self];

  _statusID = Ready;

  [_statusLabel setStringValue:@"Controller connected."];
  [self executeBlock:^{
    [self setStatus];
  } after:1.5];

  [_radioMatrix setEnabled:YES];
  [_calibrationButton setEnabled:YES];
  [_resetButton setEnabled:YES];
}

- (void)controllerDidDisconnect:(GAXboxController *)controller {
  [_connectButton setTitle:@"Connect"];
  [_triggerButton setEnabled:NO];
  [_calibrationButton setEnabled:NO];
  [_resetButton setEnabled:NO];

  _statusID = Disconnected;
  [self setStatus];

  _vhid = nil;
  _controller = nil;

  [self cleanUI];
}

- (void)controllerDidUpdateData:(GAXboxController *)controller {
  [_queue addOperationWithBlock:^{
    [self updateVHID:controller];
  }];

  if (!_isCalibrating)
    [_queue addOperationWithBlock:^{
      [self updateUI:controller];
    }];

  else if ([controller A] || [controller DPadUp]    || [controller leftBumper]  ||
           [controller B] || [controller DPadDown]  || [controller rightBumper] ||
           [controller X] || [controller DPadLeft]  || [controller view]        ||
           [controller Y] || [controller DPadRight] || [controller menu])
    _isCalibrating = NO;
}

- (void)controllerConnectionFailed:(GAXboxController *)controller withError:(NSString *)error errorCode:(int)code {
  [_statusLabel setStringValue:[NSString stringWithFormat:@"Error: %@ (code %d)", error, code]];
  [self executeBlock:^ {
    [self setStatus];
  } after:1.5];
}

#pragma mark - Utils

- (void) executeBlock:(void (^)(void))block after:(NSTimeInterval)seconds {
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC);
  dispatch_after(popTime, dispatch_get_main_queue(), block);
}

@end
