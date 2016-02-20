//
//  AnimatedGifView.h
//  AnimatedGif
//
//  Created by Marco Köhler on 09.11.15.
//  Copyright (c) 2015 Marco Köhler. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <GLUT/GLUT.h>

@interface AnimatedGifView : ScreenSaverView {
    // keep track of whether or not drawRect: should erase the background
    NSMutableArray *animationImages;
    NSInteger viewOption;
    NSInteger currFrameCount;
    NSInteger maxFrameCount;
    NSImage *img;
    NSBitmapImageRep *gifRep;
    float backgrRed;
    float backgrGreen;
    float backgrBlue;
    BOOL loadAnimationToMem;
}

- (NSOpenGLView *)createGLView;
- (float)pictureRatioFromWidth:(float)iWidth andHeight:(float)iHeight;
- (float)calcWidthFromRatio:(float)iRatio andHeight:(float)iHeight;
- (float)calcHeightFromRatio:(float)iRatio andWidth:(float)iWidth;
- (void)loadAgent;
- (void)unloadAgent;

@property (nonatomic, retain) NSOpenGLView* glView;
@property (assign) IBOutlet NSPanel *optionsPanel;
@property (assign) IBOutlet NSTextField *textFieldFileUrl;
@property (assign) IBOutlet NSSlider *sliderFpsManual;
@property (assign) IBOutlet NSButton *checkButtonSetFpsManual;
@property (assign) IBOutlet NSButton *checkButtonLoadIntoMem;
@property (assign) IBOutlet NSColorWell *colorWellBackgrColor;
@property (assign) IBOutlet NSTextField *labelFpsManual;
@property (assign) IBOutlet NSTextField *labelFpsGif;
@property (assign) IBOutlet NSSegmentedControl *segmentButtonLaunchAgent;
@property (assign) IBOutlet NSPopUpButton *popupButtonViewOptions;

@end
