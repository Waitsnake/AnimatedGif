//
//  AnimatedGifView.h
//  AnimatedGif
//
//  Created by Marco Köhler on 09.11.15.
//  Copyright (c) 2015 Marco Köhler. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>
#import <GLUT/GLUT.h>


#define LOAD_BTN                    0
#define UNLOAD_BTN                  1

#define VIEW_OPT_STRETCH_OPTIMAL    0
#define VIEW_OPT_STRETCH_MAXIMAL    1
#define VIEW_OPT_KEEP_ORIG_SIZE     2
#define VIEW_OPT_STRETCH_SMALL_SIDE 3
#define MAX_VIEW_OPT                3

#define SYNC_TO_VERTICAL            1
#define DONT_SYNC                   0

#define FRAME_COUNT_NOT_USED        -1
#define FIRST_FRAME                 0

#define DEFAULT_ANIME_TIME_INTER    1/15.0
#define GL_ALPHA_OPAQUE             1.0f
#define NS_ALPHA_OPAQUE             1.0


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
    BOOL trigByTimer;
}

- (NSOpenGLView *)createGLView;
- (float)pictureRatioFromWidth:(float)iWidth andHeight:(float)iHeight;
- (float)calcWidthFromRatio:(float)iRatio andHeight:(float)iHeight;
- (float)calcHeightFromRatio:(float)iRatio andWidth:(float)iWidth;
- (void)loadAgent;
- (void)unloadAgent;
- (BOOL)isDir:(NSString*)fileOrDir;
- (NSString *)getRandomGifFile:(NSString*)fileOrDir;
- (void)timerMethod;
- (void)enableSliderChangeInterval:(BOOL)enable;
- (void)enableSliderFpsManual:(BOOL)enable;
- (void)receiveWakeNote: (NSNotification*) note;
- (void)hideFpsFromFile:(BOOL)hide;

@property (nonatomic, retain) NSOpenGLView* glView;
@property (assign) IBOutlet NSPanel *optionsPanel;
@property (assign) IBOutlet NSTextField *textFieldFileUrl;
@property (assign) IBOutlet NSButton *checkButtonLoadIntoMem;
@property (assign) IBOutlet NSColorWell *colorWellBackgrColor;
@property (assign) IBOutlet NSSegmentedControl *segmentButtonLaunchAgent;
@property (assign) IBOutlet NSPopUpButton *popupButtonViewOptions;

@property (assign) IBOutlet NSSlider *sliderChangeInterval;
@property (assign) IBOutlet NSTextField *labelChangeInterval;
@property (assign) IBOutlet NSTextField *labelChIntT1;
@property (assign) IBOutlet NSTextField *labelChIntT2;
@property (assign) IBOutlet NSTextField *labelChIntT3;
@property (assign) IBOutlet NSTextField *labelChIntT4;

@property (assign) IBOutlet NSSlider *sliderFpsManual;
@property (assign) IBOutlet NSTextField *labelFpsManual;
@property (assign) IBOutlet NSTextField *labelFpsGif;
@property (assign) IBOutlet NSButton *checkButtonSetFpsManual;
@property (assign) IBOutlet NSTextField *labelFpsT1;
@property (assign) IBOutlet NSTextField *labelFpsT2;
@property (assign) IBOutlet NSTextField *labelFpsT3;
@property (assign) IBOutlet NSTextField *labelFpsT4;
@property (assign) IBOutlet NSTextField *labelFpsT5;
@property (assign) IBOutlet NSTextField *labelFpsT6;

@end
