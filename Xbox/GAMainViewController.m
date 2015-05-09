//
//  GAMainViewController.m
//  Xbox One Controller Enabler
//
//  Created by Guilherme Araújo on 28/03/14.
//  Copyright (c) 2014 Guilherme Araújo. All rights reserved.
//

#import "GAMainViewController.h"
#import "GAXboxController.h"
#import "GAXboxControllerCommunication.h"
#import "GAXboxControllerViewController.h"
#import "XboxOneButtonMap.h"
#import <VHID/VHIDDevice.h>
#import <WirtualJoy/WJoyDevice.h>

@interface GAMainViewController ()

@property (strong, nonatomic) IBOutlet NSTabView *controllerTabs;

@end

@implementation GAMainViewController

#pragma mark - View Controller Life Cycle

- (void)viewDidLoad {
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  queue.maxConcurrentOperationCount = 1;
  queue.name = @"Xbox Controller";

  int count = [GAXboxControllerCommunication numberOfConnectedControllers];
  for (int i = 0; i < count; ++i) {
    GAXboxControllerViewController *viewController = [[GAXboxControllerViewController alloc] initWithControllerIndex:i queue:queue];
    viewController.title = [NSString stringWithFormat:@"Controller %i", i + 1];
    [_controllerTabs addTabViewItem:[NSTabViewItem tabViewItemWithViewController:viewController]];
  }
}

@end
