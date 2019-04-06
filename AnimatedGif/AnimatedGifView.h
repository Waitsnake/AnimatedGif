//
//  AnimatedGifView.h
//  AnimatedGif
//
//  Created by Marco Köhler on 09.11.15.
//  Copyright (c) 2015 Marco Köhler. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>

#import <GLUT/GLUT.h>

@import MetalKit;
#import "Structs.h"

/* The maximum frame rate of an GIF could not go higher than 100 fps (respectively no delay/duration lower than 0.01s is possible) according to GIF89a Specification.
   Anyway whatever the theoretical maximum of an GIF might be while debuging with tool FrameMeter of "Quartz Debug" I could never reach more than 60fps whatever value aboth 60fps I use (with Metal and OpenGL).
   I read in internet this is the maximum that Quartz uses on most Apple Laptops and maybe only a few newer systems support 120fps here (answers are quit spongy at this topic). Within "Quartz Debug" it is possible to disable the "Enable Vertical Sync" option and than also 120fps where possible. But I don't find an API to switch this option outside of Quartz Debug". Furthermore the animation looks very ugly at 120fps due to tear effects, since Animation draws than more fps as the screen supports.
 
    Because of that experience I set the maximum to 60fps and this will do the job on most systems. I also doubt there are many GIFs out there that go to this theoretical maximim of 100fps.
*/
#define MAX_FRAME_RATE              60

#define LOAD_BTN                    0
#define UNLOAD_BTN                  1

#define VIEW_OPT_STRETCH_OPTIMAL    0
#define VIEW_OPT_STRETCH_MAXIMAL    1
#define VIEW_OPT_SCALE_SIZE         2
#define VIEW_OPT_STRETCH_SMALL_SIDE 3
#define MAX_VIEW_OPT                3

#define SCALE_OPT_0_10              0
#define SCALE_OPT_0_25              1
#define SCALE_OPT_0_50              2
#define SCALE_OPT_0_75              3
#define SCALE_OPT_1                 4
#define SCALE_OPT_2                 5
#define SCALE_OPT_3                 6
#define SCALE_OPT_4                 7
#define SCALE_OPT_5                 8
#define SCALE_OPT_6                 9
#define SCALE_OPT_7                 10
#define SCALE_OPT_8                 11
#define SCALE_OPT_9                 12
#define SCALE_OPT_10                13
#define MAX_SCALE_OPT               13

#define FILTER_OPT_BLUR             0
#define FILTER_OPT_SHARP            1
#define MAX_FILTER_OPT              1

#define TILE_OPT_1                  0
#define TILE_OPT_3_BY_3             1
#define MAX_TILE_OPT                1

#define SYNC_TO_VERTICAL            1
#define DONT_SYNC                   0

#define FRAME_COUNT_NOT_USED        -1
#define FIRST_FRAME                 0

#define DEFAULT_ANIME_TIME_INTER    1/15.0
#define GL_ALPHA_OPAQUE             1.0f
#define NS_ALPHA_OPAQUE             1.0
#define NEVER_CHANGE_GIF            30

#define SIZE_OF_BGRA_PIXEL          4


@interface AnimatedGifView : ScreenSaverView {
    // keep track of whether or not drawRect: should erase the background
    NSMutableArray *animationImages;
    NSInteger currFrameCount;
    NSInteger maxFrameCount;
    NSImage *img;
    NSBitmapImageRep *gifRep;
    float backgrRed;
    float backgrGreen;
    float backgrBlue;
    BOOL loadAnimationToMem;
    BOOL trigByTimer;
    NSRect screenRect;
    NSRect targetRect;
    NSInteger filter;
    NSInteger viewOption;
    NSInteger tiles;
    float scale;
    NSOpenPanel* openDlg;
    
    // Only when using OpenGL to render
    NSOpenGLView* glView;
    
    // Only when using Metal to render
    
    // The following are available after creating Metal view
    MTKView* mtlView;
    id <MTLDevice> deviceMTL;
    id <MTLCommandQueue> commandQueueMTL;
    id <MTLLibrary> defaultLibraryMTL;
    id <MTLRenderPipelineState> pipelineStateMTL;
    
    // The following are only available during rendering pass
    id <MTLCommandBuffer> commandBufferMTL;
    id <CAMetalDrawable> drawableMTL;
    id <MTLRenderCommandEncoder> renderMTL;
}

- (NSOpenGLView *)createViewGL;
- (void) startRenderGL:(BOOL)allowScale;
- (void) endRenderGL;
- (void) animateNoGifGL;
- (void) animateWithGifGL;
- (void) drawAttributedStringGL:(NSAttributedString *)attributedString atPoint:(NSPoint)point;
- (void) drawImageGL:(void *)pixelsBytes pixelWidth:(NSInteger)width pixelHeight:(NSInteger)height withFilter:(NSInteger)filter hasAlpha: (Boolean)alpha atRect:(NSRect) rect;

- (MTKView *)createViewMTL;
- (void) startRenderMTL:(BOOL)allowScale;
- (void) endRenderMTL;
- (void) animateNoGifMTL;
- (void) animateWithGifMTL;
- (void) drawAttributedStringMTL:(NSAttributedString *)attributedString atPoint:(NSPoint)point;
- (void) drawImageMTL:(void *)pixelsBytes pixelWidth:(NSInteger)width pixelHeight:(NSInteger)height withFilter:(NSInteger)filter hasAlpha: (Boolean)alpha atRect:(NSRect) rect;

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
- (void)hideFpsFromFile:(BOOL)hide;
- (BOOL)loadGifFromFile:(NSString*)gifFileName andUseManualFps: (BOOL)manualFpsActive withFps: (float)fps;
- (float)calcScaleFromScaleOption:(NSInteger)option;
- (NSRect)calcTargetRectFromOption:(NSInteger)option;
- (NSTimeInterval)getDurationFromGifFile:(NSString*)gifFileName;
- (void) receiveDisplaysChangeNote: (NSNotification*) note;

@property (assign) IBOutlet NSPanel *optionsPanel;
@property (assign) IBOutlet NSTextField *textFieldFileUrl;
@property (assign) IBOutlet NSButton *checkButtonLoadIntoMem;
@property (assign) IBOutlet NSColorWell *colorWellBackgrColor;
@property (assign) IBOutlet NSSegmentedControl *segmentButtonLaunchAgent;
@property (assign) IBOutlet NSPopUpButton *popupButtonViewOptions;
@property (assign) IBOutlet NSPopUpButton *popupButtonFilterOptions;
@property (assign) IBOutlet NSButton *checkButtonTileOptions;
@property (assign) IBOutlet NSPopUpButton *popupButtonScaleOptions;

@property (assign) IBOutlet NSTextField *labelVersion;

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

@property (assign) IBOutlet NSWindow *aboutWindow;
@property (nonatomic, strong) NSWindowController *aboutWindowController;
@property (assign) IBOutlet NSTextField *labelVersion2;
@property (assign) IBOutlet NSTextView *textLicence;
@property (assign) IBOutlet NSImageView *imgGL;
@property (assign) IBOutlet NSImageView *imgMTL;

@end
