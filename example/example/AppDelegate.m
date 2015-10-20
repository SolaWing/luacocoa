//
//  AppDelegate.m
//  example
//
//  Created by Wangxh on 15/8/8.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "AppDelegate.h"
#import "luaoc.h"
#import "lauxlib.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)openLuaoc {
    NSString* scriptsDir = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"scripts"];
    if ( [[NSFileManager defaultManager] fileExistsAtPath:scriptsDir] ){
        setenv("LUA_PATH", [[NSString stringWithFormat:@"%@/?.lua;%@/?/init.lua",
                scriptsDir, scriptsDir] UTF8String], 1);
        lua_State* L = luaoc_setup();
        NSString* initScript = [scriptsDir stringByAppendingPathComponent:@"init.lua"];
        if ( [[NSFileManager defaultManager] fileExistsAtPath:initScript] ){
            if (luaL_dofile(L, initScript.UTF8String) != 0) {
                NSLog(@" load init error:%s", lua_tostring(L, -1));
            }
        }
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    // Override point for customization after application launch.
    [self openLuaoc];

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
