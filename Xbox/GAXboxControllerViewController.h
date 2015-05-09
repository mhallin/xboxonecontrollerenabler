//
//  GAXboxControllerViewController.h
//  Xbox One Controller Enabler
//
//  Created by Magnus Hallin on 2015-05-08.
//  Copyright (c) 2015 Guilherme Araújo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GAXboxControllerViewController : NSViewController

- (instancetype)initWithControllerIndex:(int)index queue:(NSOperationQueue *)queue;

@end
