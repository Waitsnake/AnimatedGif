//
//  AnimatedGifWindowClasses.h
//  AnimatedGif
//
//  Created by Marco Köhler on 11.04.19.
//  Copyright © 2019 Marco Köhler. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// Class NSWindow needs to be changed so that AboutWindow can become a keywindow
@interface AboutWindow : NSWindow

@end

@implementation AboutWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end


// Class NSOpenPanel needs to be changed so that OpenWindow can become a keywindow
@interface OpenWindow : NSOpenPanel

@end

@implementation OpenWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end


