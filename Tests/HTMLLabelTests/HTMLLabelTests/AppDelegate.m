//
//  AppDelegate.m
//  HTMLLabelTests
//
//  Created by Nick Lockwood on 19/11/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import "AppDelegate.h"
#import "ParsingViewController.h"


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[ParsingViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
