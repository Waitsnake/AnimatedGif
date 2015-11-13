//
//  AnimatedGifView.h
//  AnimatedGif
//
//  Created by Marco Köhler on 09.11.15.
//  Copyright (c) 2015 Marco Köhler. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>

@interface AnimatedGifView : ScreenSaverView {
    // keep track of whether or not drawRect: should erase the background
    BOOL shouldStretchImg;
    NSInteger currFrameCount;
    NSInteger maxFrameCount;
    NSImage *img;
    NSBitmapImageRep *gifRep;
    float backgrRed;
    float backgrGreen;
    float backgrBlue;
}

- (float)pictureRatioFromWidth:(float)iWidth andHeight:(float)iHeight;
- (float)calcWidthFromRatio:(float)iRatio andHeight:(float)iHeight;
- (float)calcHeightFromRatio:(float)iRatio andWidth:(float)iWidth;
- (void)loadAgent;
- (void)unloadAgent;

@property (assign) IBOutlet NSPanel *optionsPanel;
@property (assign) IBOutlet NSTextField *textField1;
@property (assign) IBOutlet NSSlider *slider1;
@property (assign) IBOutlet NSButton *checkButton1;
@property (assign) IBOutlet NSButton *checkButton2;
@property (assign) IBOutlet NSColorWell *colorWell1;
@property (assign) IBOutlet NSTextField *label1;
@property (assign) IBOutlet NSSegmentedControl *segmentButton1;

@end
