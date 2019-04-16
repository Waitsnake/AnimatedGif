//
//  AnimatedGifView.m
//  AnimatedGif
//
//  Created by Marco Köhler on 09.11.15.
//  Copyright (c) 2015 Marco Köhler. All rights reserved.
//

#import "AnimatedGifView.h"


@implementation AnimatedGifView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    mtlView = nil;
    glView = nil;
    trigByTimer = FALSE;
    lastDuration = 0;
    currFrameCount = FRAME_COUNT_NOT_USED;
    self = [super initWithFrame:frame isPreview:isPreview];
    
    // initialize screensaver defaults with an default value
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                 @"file:///please/select/an/gif/animation.gif", @"GifFileName", @"30.0", @"GifFrameRate", @"NO", @"GifFrameRateManual", @"0", @"ViewOpt", @"4", @"ScaleOpt", @"1", @"FilterOpt", @"0", @"TileOpt", @"0.0", @"BackgrRed", @"0.0", @"BackgrGreen", @"0.0", @"BackgrBlue", @"NO", @"LoadAniToMem", @"5", @"ChangeInterval",nil]];
    
    if (self) {
        mtlView = [self createViewMTL];
        if (mtlView==nil)
        {
            NSLog(@"Since Metal setup was not possible try to use OpenGL setup.");
            glView = [self createViewGL]; // only use OpenGL in case there is no Metal
            if (glView==nil)
            {
                NSLog(@"OpenGL setup was not possible.");
            }
            else
            {
                NSLog(@"OpenGL setup done.");
            }
        }
        // this is just an high dummy value for animateOneFrame (not longer used)
        [self setAnimationTimeInterval:600];
    }
    
    // get the program arguments of the process
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    // check if process was startet with argument -window for window mode of screensaver and is the first instance (has only two arguments, program name and the -"window")
    if ((args.count==2) && ([args[1] isEqualToString:@"-window"]))
    {
        // Workaround: disable clock before start, since this leads to a crash with option "-window" of ScreenSaverEngine
        NSString *cmdstr = [[NSString alloc] initWithFormat:@"%@", @"defaults -currentHost write com.apple.screensaver showClock -bool NO"];
        system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
        
        NSString *pathToScreenSaverEngine = @"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine";
        NSOperatingSystemVersion osVer = [[NSProcessInfo processInfo] operatingSystemVersion];
        if (osVer.majorVersion > 10 || osVer.minorVersion > 12)
        {
            pathToScreenSaverEngine = @"/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine";
        }
        
        // This is a hell of a heck for a workaround. Since "-window" only starts one instance of ScreenSaverView, we start here additional instances of the ScreenSaverEngine itself by system call.
        NSUInteger countScreens = [NSScreen screens].count;
        if (countScreens > 1)
        {
            // additional instances needs start counting with "1" here(!) otherwise other part of code will be broken
            for(NSUInteger scr=1;scr<countScreens;scr++)
            {
                // we start additional instances of ScreenSaverEngine, but with an extra number as argument that is invalid for the parser of the ScreenSaverEngine(see Log) but that wee use to differenceate beween the instances afterwards.
                NSString *cmdstr2 = [[NSString alloc] initWithFormat:@"%@ %@ %ld &", pathToScreenSaverEngine, @"-window", scr];
                system([cmdstr2 cStringUsingEncoding:NSUTF8StringEncoding]);
            }
        }
        
    }
    
    return self;
}

- (NSOpenGLView *)createViewGL
{
    NSOpenGLPixelFormatAttribute attribs[] = {
        NSOpenGLPFADoubleBuffer, NSOpenGLPFAAccelerated,
        0
    };
    NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
    NSOpenGLView* glview = [[NSOpenGLView alloc] initWithFrame:NSZeroRect pixelFormat:format];
    
    GLint swapInterval = SYNC_TO_VERTICAL;
    [[glview openGLContext] setValues:&swapInterval forParameter: NSOpenGLCPSwapInterval];
    
    return glview;
}

- (MTKView *) createViewMTL
{
    // Does the user have any working Metal API(start with OS X 10.11 or later)?
    if (MTLCopyAllDevices == NULL)
    {
        NSLog(@"Your version of the OS does not support Metal. Requires OS X 10.11 or later.");
        return nil;
    }
    else
    {
        NSArray *devices = MTLCopyAllDevices();
        
        // Does the user have any Metal devices available? (This should be yes on all Macs made after mid-2012.)
        if (!devices || devices.count == 0)
        {
            NSLog(@"No Metal device could be found.");
            return nil;
        }
        else
        {
            NSLog(@"Metal devices could be found.");
            
            // the easy way is just using the system default metal device
            deviceMTL = MTLCreateSystemDefaultDevice();
            
            // create an Metal View that uses the metal device
            MTKView* mtlView = [[MTKView alloc] initWithFrame:NSZeroRect];
            mtlView.device = deviceMTL;
            mtlView.clearColor = MTLClearColorMake(0, 0, 0, 1);
            mtlView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
            mtlView.framebufferOnly = NO;
            mtlView.autoResizeDrawable = NO;
            // here the presentaion framerate of metal is setup. it should be equal or higher as the framerate of the gif
            mtlView.preferredFramesPerSecond = MAX_FRAME_RATE;

            // get an metal command queue
            commandQueueMTL = [deviceMTL newCommandQueue];
            
            // load the metal libary from the bundle (contains the shader code for the GPU)
            NSError *err = nil;
            defaultLibraryMTL = [deviceMTL newLibraryWithFile:[[NSBundle bundleForClass:self.class] pathForResource:@"default" ofType:@"metallib"] error:&err];
            
            // create an piple descriptor (defines porperties of an metal pipeline ) for creating an metal pipeline with it
            pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
            pipelineStateDescriptor.label = @"AnimatedGifPipeline";
            // also add the shader codes that we load from the resource bundle to the metal pipeline
            pipelineStateDescriptor.vertexFunction = [defaultLibraryMTL newFunctionWithName:@"myVertexShader"];
            pipelineStateDescriptor.fragmentFunction = [defaultLibraryMTL newFunctionWithName:@"myFragmentShader"];
            
            // setup parameters for alpha blending, but not enable it here (this is done in drawImageMTL)
            pipelineStateDescriptor.colorAttachments[0].blendingEnabled = NO;
            pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation           = MTLBlendOperationAdd;
            pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation         = MTLBlendOperationAdd;
            pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor        = MTLBlendFactorOne;
            pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor   = MTLBlendFactorOneMinusSourceAlpha;
            pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor      = MTLBlendFactorOne;
            pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

            // define the pixel format we will use with metal
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            
            // with that descriptor informations we can finaly create the metal pipeline
            pipelineStateMTL = [deviceMTL newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&err];

            NSLog(@"Metal setup done.");
            
            return mtlView;
        
        }
    }

}

- (void) drawRect:(NSRect)rect
{
    // not needed since we use timerAnimateOneFrame and left empty so that super method of NSView is not called to save same CPU time
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    if (mtlView == nil)
    {
        [glView setFrameSize:newSize];
    }
    else
    {
        [mtlView setFrameSize:newSize];
    }
}

- (BOOL)isOpaque
{
    // this keeps Cocoa from unnecessarily redrawing our superview
    return YES;
}

- (void)dealloc
{
    if (mtlView == nil)
    {
        [glView removeFromSuperview];
        glView = nil;
    }
    else
    {
        [mtlView removeFromSuperview];
        mtlView = nil;
    }
}

- (void)timerMethod
{
    // after change timer is running out this method is called
    
    // the animation of last GIF is stopped an memory cleaned, but without destroying GL view or telling the screensaver engine about it (no call of super method; handled by trigByTimer=TRUE)
    trigByTimer = TRUE;
    [self stopAnimation];
    
    // the animation is start again witch randomly pics a new GIF from folder and start the change timer again, but without telling the screensaver engine about it (no call of super method; handled by trigByTimer=TRUE)
    [self startAnimation];
    trigByTimer = FALSE;
}

- (void)startAnimation
{
    // get the program arguments of the process
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    if (trigByTimer == FALSE)
    {
        // only call super method in case startAnimation is not called by timerMethod
        [super startAnimation];
        
        if (mtlView == nil)
        {
            [self addSubview:glView];
        }
        else
        {
            [self addSubview:mtlView];
        }
        
        // bug of OSX: since 10.13 the background mode of screensaver is brocken (the ScreenSaverEngine uses for background-mode its own space that is in foreground and this space can't be accessed from the ScreenSaverView)
        // workaround: AnimatedGif use the window-mode of the ScreenSaverEngine and change the behavior of that window to an background window
        if ([self isPreview] == FALSE)
        {
            // check if process was startet with argument -window for window mode of screensaver
            if ((args.count>=2) && ([args[1] isEqualToString:@"-window"]))
            {
                int scrNum = 0; // this "0" is for the first instance, that hast no number in "args[2]"
                // only the additional instances have 3 arguments and a number in "args[2]" that starts with "1".
                // unfortunly we can not start the main instance with an 3 agrument of "0" since this breaks the start with launchd, because for ScreenSaverEngine this argument is invalid.
                if (args.count>2)
                {
                    scrNum = [args[2] intValue];
                }
                // get the one the multiple screens
                NSScreen *theScreen = [NSScreen screens][scrNum];

                // now we move the window to background level and maximize it as we need it
                [self.window setFrame:[theScreen frame] display:TRUE];
                [super setFrame:[theScreen frame]];
                [super setFrameOrigin:NSZeroPoint];
                [self.window setStyleMask:NSFullSizeContentViewWindowMask];
                [self.window setCollectionBehavior: NSWindowCollectionBehaviorStationary|NSWindowCollectionBehaviorCanJoinAllSpaces];
                [self.window setLevel:kCGDesktopWindowLevel];
                [self.window setFrame:[theScreen frame] display:TRUE];
            }
        }
        
        
        if ([self isPreview] == FALSE)
        {
            // check if process was startet with argument -window for window mode of screensaver
            if ((args.count>=2) && ([args[1] isEqualToString:@"-window"]))
            {
                // hide window since next steps need some time and look ugly
                [self.window orderOut:self];
            }
        }
    }
    
    // get filename from screensaver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    NSString *gifFileName = [defaults objectForKey:@"GifFileName"];
    manualFrameRate = [defaults floatForKey:@"GifFrameRate"];
    isManualFrameRate = [defaults boolForKey:@"GifFrameRateManual"];
    loadAnimationToMem = [defaults boolForKey:@"LoadAniToMem"];
    viewOption = [defaults integerForKey:@"ViewOpt"];
    NSInteger scaleOption = [defaults integerForKey:@"ScaleOpt"];
    NSInteger filterOption = [defaults integerForKey:@"FilterOpt"];
    NSInteger tileOption = [defaults integerForKey:@"TileOpt"];
    backgrRed = [defaults floatForKey:@"BackgrRed"];
    backgrGreen = [defaults floatForKey:@"BackgrGreen"];
    backgrBlue = [defaults floatForKey:@"BackgrBlue"];
    NSInteger changeIntervalInMin = [defaults integerForKey:@"ChangeInterval"];
    
    // In case if preview window never use the 'load into memory' feature since it initially needs much CPU time witch is bad inside the system preferences app
    if ([self isPreview])
    {
        loadAnimationToMem = FALSE;
    }
    
    // select a random file from directory or keep the file if it was already a file
    NSString *selectedGifFileName = [self getRandomGifFile:gifFileName];
    
    // load GIF image
    BOOL isFileLoaded = [self loadGifFromFile:selectedGifFileName];
    if (isFileLoaded)
    {
        currFrameCount = FIRST_FRAME;
    }
    else
    {
        currFrameCount = FRAME_COUNT_NOT_USED;
    }

    // calculate target and screen rectangle size
    screenRect = [self bounds];
    targetRect = [self calcTargetRectFromOption:viewOption];
    filter = filterOption;
    tiles = tileOption;
    if (viewOption==VIEW_OPT_SCALE_SIZE)
    {
        scale = [self calcScaleFromScaleOption:scaleOption];
    }
    else
    {
        scale = 1.0;
    }
    
    // check if it is a file or a directory
    if (isFileLoaded && [self isDir:gifFileName] && ((changeIntervalInMin) != NEVER_CHANGE_GIF))
    {

        // start a one-time timer at end of startAnimation otherwise the time for loading the GIF is part of the timer
        changeTimer = [NSTimer scheduledTimerWithTimeInterval:(changeIntervalInMin * 60)
                                         target:self
                                       selector:@selector(timerMethod)
                                       userInfo:nil
                                        repeats:NO];
    }
    
    if (trigByTimer == FALSE)
    {
        if ([self isPreview] == FALSE)
        {
            // check if process was startet with argument -window for window mode of screensaver
            if ((args.count>=2) && ([args[1] isEqualToString:@"-window"]))
            {
                // unhide window
                [self.window orderBack:self];
            }
        }
    }
    
    // Register for notification something with the display has changed
    [[NSNotificationCenter defaultCenter] addObserver: self
                                                           selector: @selector(receiveDisplaysChangeNote:)
                                                               name: NSApplicationDidChangeScreenParametersNotification
                                                             object: nil];
}

- (void) receiveDisplaysChangeNote: (NSNotification*) note
{
    // Event is fired after a change of displays
    
    // get the program arguments of the process
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    // only terminate instances startet with "-window"
    if ((args.count>=2) && ([args[1] isEqualToString:@"-window"]))
    {
        // this ScreenSaverEngine instance terminates itself
        [NSApp terminate:self];
    }
}

- (void)stopAnimation
{
    if (trigByTimer == FALSE)
    {
        // only call super method in case stopAnimation is not called by timerMethod
        [super stopAnimation];
        
        // stop change timer with end of animation (otherwise in the screensaver preview will running multiple timer each time congigure panel is closed)
        if (changeTimer != nil) {
            [changeTimer invalidate];
        }
        
        // stop an old timer if there is one
        if (animateTimer != nil) {
            [animateTimer invalidate];
        }
        lastDuration = 0;
    }
    
    if (loadAnimationToMem == TRUE)
    {
        /*clean all pre-calculated bitmap images*/
        [animationImages removeAllObjects];
        animationImages = nil;
    }
    [animationDurations removeAllObjects];
    animationDurations = nil;
    img = nil;
    currFrameCount = FRAME_COUNT_NOT_USED;
}

- (void)animateOneFrame
{
    /*
    not longer used since animationTimeInterval can not be changed during animation, but GIFs have this feature. As new way timerAnimateOneFrame is used that is triggert by animateTimer.
     */
}

- (void)timerAnimateOneFrame
{
  @autoreleasepool {
      
    [self lockFocus];

    if (currFrameCount == FRAME_COUNT_NOT_USED)
    {
        // FRAME_COUNT_NOT_USED means no image is loaded and so we clear the screen with the set background color and print an indication message
        
        if (mtlView == nil)
        {
            [self animateNoGifGL];
        }
        else
        {
            [self animateNoGifMTL];
        }
    }
    else
    {
        // draw the selected frame

        if (mtlView == nil)
        {
            [self animateWithGifGL];
        }
        else
        {
            [self animateWithGifMTL];
        }
        
    
        //calculate next frame of GIF to show
        if (currFrameCount < maxFrameCount-1)
        {
            currFrameCount++;
        }
        else
        {
            currFrameCount = FIRST_FRAME;
        }
        
        [self setAnimationIntervalAtFrame:currFrameCount];
    }
    
    [self unlockFocus];
      
    return;
  }
}

-(IBAction)aboutClick:(id)sender {
    if (!_aboutWindowController)
    {
        // load about window from nib
        [[NSBundle bundleForClass:[self class]] loadNibNamed:@"About" owner:self topLevelObjects:nil];
        
        // prepare about window with content
        NSString *version = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
        [self.labelVersion2 setStringValue:version];
        [self.textLicence setEditable:NO];
        NSError *err = nil;
        NSString *path =[[NSBundle bundleForClass:[self class]] pathForResource:@"LICENSE" ofType:@"md"];
        NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
        if (contents)
        {
            NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
            NSMutableAttributedString *attrString;
            if ([osxMode isEqualToString:@"Dark"])
            {
                NSDictionary *attributes = @{ NSForegroundColorAttributeName : [NSColor lightGrayColor]};
                attrString = [[NSMutableAttributedString alloc] initWithString:contents attributes:attributes];
            }
            else
            {
                attrString = [[NSMutableAttributedString alloc] initWithString:contents];
            }

            [[self.textLicence textStorage] appendAttributedString:attrString];
        }
        
        // Create the modal controller for about window
        _aboutWindowController = [[NSWindowController alloc] initWithWindow:self.aboutWindow];
        
        // Show window
        [_aboutWindowController showWindow:self];
        // unfortunately the modal not longer works since 10.14 and crashes the whole app
        //[NSApp runModalForWindow:self.aboutWindow];
    }
    else
    {
        // make it visible again
        if (self.aboutWindow.visible == NO)
        {
            [_aboutWindowController showWindow:self];
        }
        else
        {
            [_aboutWindowController close];
            [_aboutWindowController showWindow:self];
        }
    }
}

- (BOOL)hasConfigureSheet
{
    // tell ScreenSaverEngine that screensaver has an Options dialog
    return YES;
}

- (NSWindow*)configureSheet
{
    // Load XIB File that contains the Options dialog
    [[NSBundle bundleForClass:[self class]] loadNibNamed:@"Options" owner:self topLevelObjects:nil];
    
    // get filename from screensaver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    NSString *gifFileName = [defaults objectForKey:@"GifFileName"];
    float frameRate = [defaults floatForKey:@"GifFrameRate"];
    BOOL frameRateManual = [defaults boolForKey:@"GifFrameRateManual"];
    BOOL loadAniToMem = [defaults boolForKey:@"LoadAniToMem"];
    float bgrRed = [defaults floatForKey:@"BackgrRed"];
    float bgrGreen = [defaults floatForKey:@"BackgrGreen"];
    float bgrBlue = [defaults floatForKey:@"BackgrBlue"];
    NSInteger viewOpt = [defaults integerForKey:@"ViewOpt"];
    NSInteger scaleOpt = [defaults integerForKey:@"ScaleOpt"];
    NSInteger filterOpt = [defaults integerForKey:@"FilterOpt"];
    NSInteger tileOpt = [defaults integerForKey:@"TileOpt"];
    NSInteger changeInter = [defaults integerForKey:@"ChangeInterval"];
    
    // in the rarely case of an invalid value from default file we set an valid option
    if (viewOpt > MAX_VIEW_OPT)
    {
        viewOpt = VIEW_OPT_STRETCH_OPTIMAL;
    }
    
    // in the rarely case of an invalid value from default file we set an valid option
    if (scaleOpt > MAX_SCALE_OPT)
    {
        scaleOpt = SCALE_OPT_1;
    }
    
    // in the rarely case of an invalid value from default file we set an valid option
    if (filterOpt > MAX_FILTER_OPT)
    {
        filterOpt = FILTER_OPT_SHARP;
    }
    
    // in the rarely case of an invalid value from default file we set an valid option
    if (tileOpt > MAX_TILE_OPT)
    {
        tileOpt = TILE_OPT_1;
    }
    
    if (viewOpt == VIEW_OPT_SCALE_SIZE)
    {
        [self.popupButtonScaleOptions setEnabled:YES];
    }
    else
    {
        [self.popupButtonScaleOptions setEnabled:NO];
    }
    
    if ([self isDir:gifFileName])
    {
        // if we have an directory an fps value for a file makes not much sense
        // we could calculate it for an randomly selected file but this would make thinks to complex
        [self.labelFpsGif setStringValue:NSLocalizedStringFromTableInBundle(@"dir",@"Localizable",[NSBundle bundleForClass:[self class]],nil)];
        [self hideFpsFromFile:YES];
        
        // enable time interval slider only in case that an directory is selected
        [self enableSliderChangeInterval:YES];
    }
    else
    {
        // set file fps in GUI
        NSTimeInterval duration = [self getDurationFromFile:gifFileName atFrame:FIRST_FRAME];
        float fps = 1/duration;
        [self.labelFpsGif setStringValue:[NSString stringWithFormat:@"%2.1f", fps]];
        [self hideFpsFromFile:NO];
        
        // disable time interval slider in case an file is selected
        [self enableSliderChangeInterval:NO];
    }
    
    if (mtlView==nil)
    {
        if (glView==nil)
        {
            [self.labelRender setStringValue:NSLocalizedStringFromTableInBundle(@"renderNO", @"Localizable",[NSBundle bundleForClass:[self class]], nil)];
        }
        else
        {
            [self.labelRender setStringValue:NSLocalizedStringFromTableInBundle(@"renderGL", @"Localizable",[NSBundle bundleForClass:[self class]], nil)];
        }
    }
    else
    {
        [self.labelRender setStringValue:NSLocalizedStringFromTableInBundle(@"renderMTL", @"Localizable",[NSBundle bundleForClass:[self class]], nil)];
    }
    [self.labelRender setTextColor:[NSColor lightGrayColor]];
    
    // set the visible value in dialog to the last saved value
    NSString *version = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    [self.labelVersion setStringValue:version];
    [self.textFieldFileUrl setStringValue:gifFileName];
    [self.sliderFpsManual setDoubleValue:frameRate];
    if (tileOpt == TILE_OPT_1)
    {
        [self.checkButtonTileOptions setState:NO];
    }
    else
    {
        [self.checkButtonTileOptions setState:YES];
    }
    [self.checkButtonSetFpsManual setState:frameRateManual];
    [self.checkButtonLoadIntoMem setState:loadAniToMem];
    [self.popupButtonViewOptions selectItemWithTag:viewOpt];
    [self.popupButtonScaleOptions selectItemWithTag:scaleOpt];
    [self.popupButtonFilterOptions selectItemWithTag:filterOpt];
    [self.sliderChangeInterval setIntegerValue:changeInter];
    if ([self.sliderChangeInterval intValue] == NEVER_CHANGE_GIF)
    {
        [self.labelChangeInterval setStringValue:[self.labelChIntT4 stringValue]];
    }
    else
    {
        [self.labelChangeInterval setStringValue:[self.sliderChangeInterval stringValue]];
    }
    [self enableSliderFpsManual:frameRateManual];
    [self.labelFpsManual setStringValue:[self.sliderFpsManual stringValue]];
    [self.colorWellBackgrColor setColor:[NSColor colorWithRed:bgrRed green:bgrGreen blue:bgrBlue alpha:NS_ALPHA_OPAQUE]];
    
    // set segment button depending if the launch-agent is active or not
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.waitsnake.animatedgif.plist"];
    BOOL launchAgentFileExists = [[NSFileManager defaultManager] fileExistsAtPath:userLaunchAgentsPath];
    if (launchAgentFileExists == YES)
    {
        self.segmentButtonLaunchAgent.selectedSegment = LOAD_BTN;
    }
    else
    {
        self.segmentButtonLaunchAgent.selectedSegment = UNLOAD_BTN;
    }
    
    // return the new created options dialog
    return self.optionsPanel;
}

- (IBAction)changeViewOption:(id)sender {
    NSPopUpButton *control = (NSPopUpButton *)sender;
    NSInteger viewOption = [control selectedTag];
    
    if (viewOption == VIEW_OPT_SCALE_SIZE)
    {
        [self.popupButtonScaleOptions setEnabled:YES];
    }
    else
    {
        [self.popupButtonScaleOptions setEnabled:NO];
    }
}

- (IBAction)navigateSegmentButton:(id)sender
{
    // check witch segment of segment button was pressed and than start the according method
    NSSegmentedControl *control = (NSSegmentedControl *)sender;    
    NSInteger selectedSeg = [control selectedSegment];
    
    switch (selectedSeg) {
        case LOAD_BTN:
            [self loadAgent];
            break;
        case UNLOAD_BTN:
            [self unloadAgent];
            break;
        default:
            break;
    }
}

- (IBAction)closeConfigOk:(id)sender
{
    // read values from GUI elements
    BOOL defaultsChanged = FALSE;
    float frameRate = [self.sliderFpsManual floatValue];
    NSString *gifFileName = [self.textFieldFileUrl stringValue];
    BOOL frameRateManual = self.checkButtonSetFpsManual.state;
    BOOL loadAniToMem = self.checkButtonLoadIntoMem.state;
    NSInteger viewOpt = self.popupButtonViewOptions.selectedTag;
    NSInteger scaleOpt = self.popupButtonScaleOptions.selectedTag;
    NSInteger filterOpt = self.popupButtonFilterOptions.selectedTag;
    NSColor *colorPicked = self.colorWellBackgrColor.color;
    NSInteger changeInt = [self.sliderChangeInterval integerValue];
    NSInteger tileOpt = 0;
    if (self.checkButtonTileOptions.state == NO)
    {
        tileOpt = TILE_OPT_1;
    }
    else
    {
        tileOpt = TILE_OPT_3_BY_3;
    }
    
    // init access to screensaver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    // check for changes in default values first
    if ([gifFileName isEqualToString:[defaults objectForKey:@"GifFileName"]]==FALSE)
    {
        defaultsChanged = TRUE;
    }
    if (fabsf([defaults floatForKey:@"GifFrameRate"]-frameRate)>0.01)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults boolForKey:@"GifFrameRateManual"] != frameRateManual)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults boolForKey:@"LoadAniToMem"] != loadAniToMem)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults integerForKey:@"ViewOpt"] != viewOpt)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults integerForKey:@"ScaleOpt"] != scaleOpt)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults integerForKey:@"FilterOpt"] != filterOpt)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults integerForKey:@"TileOpt"] != tileOpt)
    {
        defaultsChanged = TRUE;
    }
    if ([defaults integerForKey:@"ChangeInterval"] != changeInt)
    {
        defaultsChanged = TRUE;
    }
    if (fabs([defaults floatForKey:@"BackgrRed"]-colorPicked.redComponent)>0.01)
    {
        defaultsChanged = TRUE;
    }
    if (fabs([defaults floatForKey:@"BackgrGreen"]-colorPicked.greenComponent)>0.01)
    {
        defaultsChanged = TRUE;
    }
    if (fabs([defaults floatForKey:@"BackgrBlue"]-colorPicked.blueComponent)>0.01)
    {
        defaultsChanged = TRUE;
    }
    // write new default values
    [defaults setObject:gifFileName forKey:@"GifFileName"];
    [defaults setFloat:frameRate forKey:@"GifFrameRate"];
    [defaults setBool:frameRateManual forKey:@"GifFrameRateManual"];
    [defaults setBool:loadAniToMem forKey:@"LoadAniToMem"];
    [defaults setInteger:viewOpt forKey:@"ViewOpt"];
    [defaults setInteger:scaleOpt forKey:@"ScaleOpt"];
    [defaults setInteger:filterOpt forKey:@"FilterOpt"];
    [defaults setInteger:tileOpt forKey:@"TileOpt"];
    [defaults setFloat:colorPicked.redComponent forKey:@"BackgrRed"];
    [defaults setFloat:colorPicked.greenComponent forKey:@"BackgrGreen"];
    [defaults setFloat:colorPicked.blueComponent forKey:@"BackgrBlue"];
    [defaults setInteger:changeInt forKey:@"ChangeInterval"];
    [defaults synchronize];
    
    // calculate target and screen rectangle size
    screenRect = [self bounds];
    targetRect = [self calcTargetRectFromOption:viewOpt];
    // set new values to object attributes
    backgrRed = colorPicked.redComponent;
    backgrGreen = colorPicked.greenComponent;
    backgrBlue = colorPicked.blueComponent;
    viewOption = viewOpt;
    filter = filterOpt;
    tiles = tileOpt;
    if (viewOption==VIEW_OPT_SCALE_SIZE)
    {
        scale = [self calcScaleFromScaleOption:scaleOpt];
    }
    else
    {
        scale = 1.0;
    }
    
    // close color dialog and options dialog
    [[NSColorPanel sharedColorPanel] close];
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
    
    // check if any default value has changed and background mode is active
    if ((defaultsChanged==TRUE) && (self.segmentButtonLaunchAgent.selectedSegment == LOAD_BTN))
    {
        // in this case stop and restart ScreenSaverEngine
        [self unloadAgent];
        [self loadAgent];
    }
    
    if (_aboutWindowController)
    {
        [_aboutWindowController close];
        _aboutWindowController = nil;
    }
    
    if (openDlg)
    {
        [openDlg close];
        openDlg = nil;
    }
}

- (IBAction)closeConfigCancel:(id)sender
{
    // close color dialog and options dialog
    [[NSColorPanel sharedColorPanel] close];
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
    
    if (_aboutWindowController)
    {
        [_aboutWindowController close];
        _aboutWindowController = nil;
    }
    
    if (openDlg)
    {
        [openDlg close];
        openDlg = nil;
    }
}

- (IBAction)pressCheckboxSetFpsManual:(id)sender
{
    // enable or disable slider depending on checkbox
    BOOL frameRateManual = self.checkButtonSetFpsManual.state;
    if (frameRateManual)
    {
        [self enableSliderFpsManual:YES];
    }
    else
    {
        [self enableSliderFpsManual:NO];
    }
}

- (IBAction)selectSliderFpsManual:(id)sender
{
    // update label with actual selected value of slider
    [self.labelFpsManual setStringValue:[self.sliderFpsManual stringValue]];
}

- (IBAction)selectSliderChangeInterval:(id)sender
{
    // update label with actual selected value of slider
    if ([self.sliderChangeInterval intValue] == NEVER_CHANGE_GIF)
    {
        [self.labelChangeInterval setStringValue:[self.labelChIntT4 stringValue]];
    }
    else
    {
        [self.labelChangeInterval setStringValue:[self.sliderChangeInterval stringValue]];
    }
}

- (void)enableSliderChangeInterval:(BOOL)enable
{
    if (enable==TRUE)
    {
        [self.sliderChangeInterval setEnabled:YES];
        [self.labelChangeInterval setTextColor:[NSColor blackColor]];
        [self.labelChIntT1 setTextColor:[NSColor blackColor]];
        [self.labelChIntT2 setTextColor:[NSColor blackColor]];
        [self.labelChIntT3 setTextColor:[NSColor blackColor]];
        [self.labelChIntT4 setTextColor:[NSColor blackColor]];
    }
    else
    {
        [self.sliderChangeInterval setEnabled:NO];
        [self.labelChangeInterval setTextColor:[NSColor lightGrayColor]];
        [self.labelChIntT1 setTextColor:[NSColor lightGrayColor]];
        [self.labelChIntT2 setTextColor:[NSColor lightGrayColor]];
        [self.labelChIntT3 setTextColor:[NSColor lightGrayColor]];
        [self.labelChIntT4 setTextColor:[NSColor lightGrayColor]];
    }
}

- (void)enableSliderFpsManual:(BOOL)enable
{
    if (enable==TRUE)
    {
        [self.sliderFpsManual setEnabled:YES];
        [self.labelFpsGif setTextColor:[NSColor blackColor]];
        [self.labelFpsManual setTextColor:[NSColor blackColor]];
        [self.labelFpsT1 setTextColor:[NSColor blackColor]];
        [self.labelFpsT2 setTextColor:[NSColor blackColor]];
        [self.labelFpsT3 setTextColor:[NSColor blackColor]];
        [self.labelFpsT4 setTextColor:[NSColor blackColor]];
        [self.labelFpsT5 setTextColor:[NSColor blackColor]];
        [self.labelFpsT6 setTextColor:[NSColor blackColor]];
    }
    else
    {
        [self.sliderFpsManual setEnabled:NO];
        [self.labelFpsGif setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsManual setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsT1 setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsT2 setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsT3 setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsT4 setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsT5 setTextColor:[NSColor lightGrayColor]];
        [self.labelFpsT6 setTextColor:[NSColor lightGrayColor]];
    }
}

- (void)hideFpsFromFile:(BOOL)hide
{
    if (hide==TRUE)
    {
        [self.labelFpsGif setHidden:YES];
        [self.labelFpsT2 setHidden:YES];
        [self.labelFpsT3 setHidden:YES];
    }
    else
    {
        [self.labelFpsGif setHidden:NO];
        [self.labelFpsT2 setHidden:NO];
        [self.labelFpsT3 setHidden:NO];
    }
}

- (IBAction)sendFileButtonAction:(id)sender
{
    
    if (!openDlg)
    {
        // if there is no OpenWindow create a new one
        
        openDlg = [OpenWindow openPanel];
    
        // Since the open dialog can no longer opend modal since 10.14 at least we give it a title
        [openDlg setMessage:NSLocalizedStringFromTableInBundle(@"titleopendlg", @"Localizable",[NSBundle bundleForClass:[self class]], nil)];
        
        // Enable the selection of files in the dialog.
        [openDlg setCanChooseFiles:YES];
        
        // Enable the selection of directories in the dialog.
        [openDlg setCanChooseDirectories:YES];
        
        // Disable the selection of more than one file
        [openDlg setAllowsMultipleSelection:NO];

        // set dialog to one level above of last selected file/directory
        if ([self isDir:[self.textFieldFileUrl stringValue]])
        {
            // in case of an directory remove one level of path before open it
            [openDlg setDirectoryURL:[[NSURL URLWithString:[self.textFieldFileUrl stringValue]] URLByDeletingLastPathComponent]];
        }
        else
        {
            // in case of an file remove two level of path before open it
            [openDlg setDirectoryURL:[[[NSURL URLWithString:[self.textFieldFileUrl stringValue]] URLByDeletingLastPathComponent] URLByDeletingLastPathComponent]];
        }
        
        // try to 'focus' only on GIF files (Yes, I know all image types are working with NSImage)
        [openDlg setAllowedFileTypes:[[NSArray alloc] initWithObjects:@"gif", @"GIF", @"png", @"PNG", nil]];

    }
    else
    {
        // if there is a OpenWindow just close it, it will be reopend in next step with beginWithCompletionHandler
        [openDlg close];
    }
    
    // Display the dialog.  If the OK button was pressed,
    // process the files.
    
    // unfortunately [openDlg runModal] crashes when selecting a single file
    // as workaround [openDlg runModal] is replaced by [openDlg beginWithCompletionHandler:]
    [openDlg beginWithCompletionHandler:^(NSInteger result)
     {
         
         //if the result is NSOKButton
         //the user selected a file
         
         if (result==NSModalResponseOK)
         {
             
             // Get an array containing the full filenames of all
             // files and directories selected.
             NSArray* files = [self->openDlg URLs];
             
             NSURL *newSelectedFileOrDir = [files objectAtIndex:0];
             
             // set GUI element with selected URL
             [self.textFieldFileUrl setStringValue:newSelectedFileOrDir.absoluteString];
             
             
             if ([self isDir:newSelectedFileOrDir.absoluteString])
             {
                 // if we have an directory an fps value for a file makes not much sense
                 // we could calculate it for an randomly selected file but this would make thinks to complex
                 [self.labelFpsGif setStringValue:NSLocalizedStringFromTableInBundle(@"dir",@"Localizable",[NSBundle bundleForClass:[self class]],nil)];
                 [self hideFpsFromFile:YES];
                 
                 // enable time interval slider only in case that an directory is selected
                 [self enableSliderChangeInterval:YES];
             }
             else
             {
                 // update file fps in GUI
                 NSTimeInterval duration = [self getDurationFromFile:[NSURL URLWithString:newSelectedFileOrDir.absoluteString].absoluteString atFrame:FIRST_FRAME];
                 float fps = 1/duration;
                 [self.labelFpsGif setStringValue:[NSString stringWithFormat:@"%2.1f", fps]];
                 [self hideFpsFromFile:NO];
                 
                 // disable time interval slider only in case that an file is selected
                 [self enableSliderChangeInterval:NO];
             }
             [self->openDlg close];
         }
         else if (result== NSModalResponseCancel)
         {
             [self->openDlg close];
         }
     }];
}

- (void)loadAgent
{
    // create the plist agent file
    NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
    
    // check if Launch-Agent directory is there or not
    NSString *userLaunchAgentsDir = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents"];
    BOOL launchAgentDirExists = [[NSFileManager defaultManager] fileExistsAtPath:userLaunchAgentsDir];
    if (launchAgentDirExists == NO)
    {
        // if directory is not there create it
        [[NSFileManager defaultManager] createDirectoryAtPath:userLaunchAgentsDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    
    NSString *pathToScreenSaverEngine = @"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine";
    NSOperatingSystemVersion osVer = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (osVer.majorVersion > 10 || osVer.minorVersion > 12)
    {
        pathToScreenSaverEngine = @"/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine";
    }
    
    // set values here...
    NSDictionary *cfg  = @{@"Label":@"com.waitsnake.animatedgif", @"ProgramArguments":@[pathToScreenSaverEngine,@"-window"], @"KeepAlive":@{@"OtherJobEnabled":@{@"com.apple.SystemUIServer.agent":@YES,@"com.apple.Finder":@YES,@"com.apple.Dock.agent":@YES}}, @"ThrottleInterval":@0,@"ProcessType":@"Interactive",@"LegacyTimers":@YES};
    [plist addEntriesFromDictionary:cfg];
    
    // saves the agent plist file
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.waitsnake.animatedgif.plist"];
    [plist writeToFile:userLaunchAgentsPath atomically:YES];
    [plist removeAllObjects];
    
    // Workaround: disable clock before start, since this leads to a crash with option "-window" of ScreenSaverEngine
    NSString *cmdstr2 = [[NSString alloc] initWithFormat:@"%@", @"defaults -currentHost write com.apple.screensaver showClock -bool NO"];
    system([cmdstr2 cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // start the launch agent
    NSString *cmdstr = [[NSString alloc] initWithFormat:@"launchctl load %@ &", userLaunchAgentsPath];
    system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
    
}

- (void)unloadAgent
{
    // stop the launch agent
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.waitsnake.animatedgif.plist"];
    NSString *cmdstr = [[NSString alloc] initWithFormat:@"%@%@", @"launchctl unload ", userLaunchAgentsPath];
    system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // remove the plist agent file
    [[NSFileManager defaultManager] removeItemAtPath:userLaunchAgentsPath error:nil];
}

- (float)pictureRatioFromWidth:(float)iWidth andHeight:(float)iHeight
{
    return iWidth/iHeight;
}

- (float)calcWidthFromRatio:(float)iRatio andHeight:(float)iHeight
{
    return iRatio*iHeight;
}

- (float)calcHeightFromRatio:(float)iRatio andWidth:(float)iWidth
{
    return iWidth/iRatio;
}

- (BOOL)isDir:(NSString*)fileOrDir
{
    BOOL pathExist = FALSE;
    BOOL isDir = FALSE;
    
    // create an NSURL object from the NSString containing an URL
    NSURL *fileOrDirUrl = [NSURL URLWithString:fileOrDir];
    
    // fileExistsAtPath:isDirectory only works with classical Path
    NSString *fileOrDirPath = [fileOrDirUrl path];
    
    // check if user selected an directory or path
    pathExist = [[NSFileManager defaultManager] fileExistsAtPath:fileOrDirPath isDirectory:&isDir];
    
    if (pathExist==TRUE)
    {
        // path was found
        
        if (isDir==TRUE)
        {
            return TRUE;
        }
        else
        {
            return FALSE;
        }
    }
    else
    {
        return FALSE;
    }
}

- (NSString *)getRandomGifFile:(NSString*)fileOrDir
{
    // check if it is a file or directory
    BOOL isDir = [self isDir:fileOrDir];

    if (isDir==TRUE)
    {
        // we have an directory
            
        // an array of all files types and also all sub-directories
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL URLWithString:fileOrDir] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
            
        // create an filter for GIF files
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension IN {'gif','png'}"];
            
        // apply filer for GIF files only to an new array
        NSArray *filesFilter = [files filteredArrayUsingPredicate:predicate];

        if (filesFilter)
        {
            // directory includes one or more files
                
            // how many GIF files we have found
            NSInteger numberOfFiles = [filesFilter count];
                
            // generate an random number with upper boundary of the number of found GIF files
            NSInteger randFile = (NSInteger)arc4random_uniform((u_int32_t)numberOfFiles);
            
            if (numberOfFiles>0)
            {
                // return a NSString of with an URL of the randomly selected GIF in the list
                return [[filesFilter objectAtIndex:randFile] absoluteString];
            }
            else
            {
                // directory includes files, but not a single GIF file
                
                // return an empty NSString
                return @"";
            }
        }
        else
        {
            // directory includes not a single file
                
            // return an empty NSString
            return @"";
        }
        
    }
    else
    {
        // a file was found
            
        // return string as it is
        return fileOrDir;
    }

}

- (float)calcScaleFromScaleOption:(NSInteger)option
{
    float scale = 1.0;
    switch (option) {
        case SCALE_OPT_0_10:
            scale = 0.1;
            break;
        case SCALE_OPT_0_25:
            scale = 0.25;
            break;
        case SCALE_OPT_0_50:
            scale = 0.5;
            break;
        case SCALE_OPT_0_75:
            scale = 0.75;
            break;
        case SCALE_OPT_1:
            scale = 1.0;
            break;
        case SCALE_OPT_2:
            scale = 2.0;
            break;
        case SCALE_OPT_3:
            scale = 3.0;
            break;
        case SCALE_OPT_4:
            scale = 4.0;
            break;
        case SCALE_OPT_5:
            scale = 5.0;
            break;
        case SCALE_OPT_6:
            scale = 6.0;
            break;
        case SCALE_OPT_7:
            scale = 7.0;
            break;
        case SCALE_OPT_8:
            scale = 8.0;
            break;
        case SCALE_OPT_9:
            scale = 9.0;
            break;
        case SCALE_OPT_10:
            scale = 10.0;
            break;
        default:
            scale = 1.0;
            break;
    }
    return scale;
}

- (NSRect)calcTargetRectFromOption:(NSInteger)option
{
    // set some values screensaver and GIF image size
    NSRect mainScreenRect = [[NSScreen mainScreen] frame];
    NSRect screenRe = [self bounds];
    NSRect targetRe = screenRe;
    float screenRatio = [self pictureRatioFromWidth:screenRe.size.width andHeight:screenRe.size.height];
    float imgRatio = [self pictureRatioFromWidth:img.size.width andHeight:img.size.height];
    CGFloat scaledHeight;
    CGFloat scaledWidth;
    
    if (option==VIEW_OPT_STRETCH_OPTIMAL)
    {
        // fit image optimal to screen
        if (imgRatio >= screenRatio)
        {
            targetRe.size.height = [self calcHeightFromRatio:imgRatio andWidth:screenRe.size.width];
            targetRe.origin.y = (screenRe.size.height - targetRe.size.height)/2;
            targetRe.size.width = screenRe.size.width;
            targetRe.origin.x = screenRe.origin.x;
        }
        else
        {
            targetRe.size.width = [self calcWidthFromRatio:imgRatio andHeight:screenRe.size.height];
            targetRe.origin.x = (screenRe.size.width - targetRe.size.width)/2;
            targetRe.size.height = screenRe.size.height;
            targetRe.origin.y = screenRe.origin.y;
        }
    }
    else if (option==VIEW_OPT_STRETCH_MAXIMAL)
    {
        // stretch image maximal to screen
        targetRe = screenRe;
    }
    else if (option==VIEW_OPT_SCALE_SIZE)
    {
        if ([self isPreview] == FALSE)
        {
            // in case of NO preview mode: simply keep original size of image
            targetRe.size.height = img.size.height;
            targetRe.size.width = img.size.width;
            targetRe.origin.y = (screenRe.size.height - img.size.height)/2;
            targetRe.origin.x = (screenRe.size.width - img.size.width)/2;
        }
        else
        {
            // in case of preview mode: we also need to calculate the ratio between the size of the physical main screen and the size of the preview window to scale the image down.
            scaledHeight = screenRe.size.height / mainScreenRect.size.height * img.size.height;
            scaledWidth = screenRe.size.width / mainScreenRect.size.width * img.size.width;
            targetRe.size.height = scaledHeight;
            targetRe.size.width = scaledWidth;
            targetRe.origin.y = (screenRe.size.height - scaledHeight)/2;
            targetRe.origin.x = (screenRe.size.width - scaledWidth)/2;
        }
    }
    else if (option==VIEW_OPT_STRETCH_SMALL_SIDE)
    {
        // stretch image to smallest side
        if (imgRatio >= screenRatio)
        {
            targetRe.size.height = screenRe.size.height;
            targetRe.origin.y = screenRe.origin.y;
            targetRe.size.width = [self calcWidthFromRatio:imgRatio andHeight:screenRe.size.height];
            targetRe.origin.x = -1*(targetRe.size.width - screenRe.size.width)/2;
        }
        else
        {
            targetRe.size.width = screenRe.size.width;
            targetRe.origin.x = screenRe.origin.x;
            targetRe.size.height = [self calcHeightFromRatio:imgRatio andWidth:screenRe.size.width];
            targetRe.origin.y = -1*(targetRe.size.height - screenRe.size.height)/2;
        }
    }
    else
    {
        /*default is VIEW_OPT_STRETCH_MAXIMAL*/
        // stretch image maximal to screen
        targetRe = screenRe;
    }

    return targetRe;
}

- (BOOL)loadGifFromFile:(NSString*)gifFileName;
{
    // load the GIF
    img = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:gifFileName]];
    
    // check if a GIF was loaded
    if (img)
    {
        // get an NSBitmapImageRep that we need to get to the bitmap data and properties of GIF
        imgRep = (NSBitmapImageRep *)[[img representations] objectAtIndex:FIRST_FRAME];
        // get max number of frames
        // get number of frames in case it is an GIF
        maxFrameCount = [[imgRep valueForProperty: NSImageFrameCount] integerValue];
        if (maxFrameCount == 0)
        {
            // if it was not a GIF than NSImageFrameCount will return '0' and so we look to the number of representations (this is for GIF allways '1', but for PNG it could be a greater number)
            maxFrameCount = [[img representations] count];
        }
        
        // load all fps data from the file and store them to memory
        CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) [NSURL URLWithString:gifFileName], NULL);
        if (source)
        {
            animationDurations = [[NSMutableArray alloc] init];
            for(NSUInteger frame=0;frame<maxFrameCount;frame++)
            {
                CFDictionaryRef cfdProperties = CGImageSourceCopyPropertiesAtIndex(source, frame, nil);
                NSDictionary *properties = CFBridgingRelease(cfdProperties);
                NSNumber *durationGIF = [[properties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                                         objectForKey:(__bridge NSString *) kCGImagePropertyGIFUnclampedDelayTime];
                //scale duration by 1000 to get ms, because it is in sec and a fraction between 1 and 0
                NSInteger durMs = [durationGIF doubleValue] * 1000.0;
                // We want to catch the case that duration is 0ms (infinity fps!), because vale was not set in frame 0 frame of GIF
                if (durMs == 0)
                {
                    // Support of animated PNG start with macOS 10.10 and we can not use this API on lower systems.
                    // Because of ths on lower systems a APNG will stand still like an normal PNG.
                    NSNumber *durationPNG = 0;
                    NSOperatingSystemVersion osVer = [[NSProcessInfo processInfo] operatingSystemVersion];
                    if (osVer.majorVersion > 10 || osVer.minorVersion >= 10)
                    {
                        durationPNG = [[properties objectForKey:(__bridge NSString *)kCGImagePropertyPNGDictionary]
                                       objectForKey:(__bridge NSString *) kCGImagePropertyAPNGUnclampedDelayTime];
                    }
                    durMs = [durationPNG doubleValue] * 1000.0;
                    if (durMs == 0)
                    {
                        [animationDurations addObject:[[NSNumber alloc] initWithDouble:1/(MAX_FRAME_RATE*1.0)]];
                    }
                    else
                    {
                        [animationDurations addObject:durationPNG];
                    }
                }
                else
                {
                    [animationDurations addObject:durationGIF];
                }
            }
            CFRelease(source);
        }
            
        
        // setup FPS of loaded GIF
        [self setAnimationIntervalAtFrame:FIRST_FRAME];
        
        // in case of no review mode and active config option create an array in memory with all frames of bitmap in bitmap format (can be used directly as OpenGL texture)
        if (loadAnimationToMem == TRUE)
        {
            animationImages = [[NSMutableArray alloc] init];
            for(NSUInteger frame=0;frame<maxFrameCount;frame++)
            {
                [imgRep setProperty:NSImageCurrentFrame withValue:@(frame)];
                // bitmapData needs most CPU time during animation.
                // thats why we execute bitmapData here during startAnimation and not in animateOneFrame. the start of screensaver will be than slower of cause, but during animation itself we need less CPU time
                unsigned char *data = [imgRep bitmapData];
                unsigned long size = [imgRep bytesPerPlane]*sizeof(unsigned char);
                // copy the bitmap data into an NSData object, that can be save transferred to animateOneFrame
                NSData *imgData = [[NSData alloc] initWithBytes:data length:size];
                [animationImages addObject:imgData];
                
            }
        }
        
        // GIF was loaded
        return TRUE;
    }
    else
    {
        // there was no GIF loaded
        return FALSE;
    }
}

- (void)setAnimationIntervalAtFrame:(NSInteger)frame
{
    NSTimeInterval duration = 1;
    if(isManualFrameRate)
    {
        // set frame rate manual
        
        // allow no fps larger as maximum MAX_FRAME_RATE
        if (manualFrameRate > MAX_FRAME_RATE)
        {
            duration = 1/MAX_FRAME_RATE;
        }
        else
        {
            duration = 1/manualFrameRate;
        }
    }
    else
    {
        // set frame duration from data from gif file
        if (animationDurations != nil)
        {
            duration = [[animationDurations objectAtIndex:frame] doubleValue];
        }
        
        float fps_for_duration = 1/duration;
        
        // allow no fps larger as maximum MAX_FRAME_RATE
        if (fps_for_duration > MAX_FRAME_RATE)
        {
            duration = 1/MAX_FRAME_RATE;
        }
        else
        {
            // duration already set
        }
        
    }
    
    // only change timer when there is an change needed
    if (lastDuration != duration)
    {
        // old way to change timer interval for animateOneFrame. but it can not changed during animation running.
        //[self setAnimationTimeInterval:duration];
        
        // stop an old timer if there is one
        if (animateTimer != nil) {
            [animateTimer invalidate];
        }
    
        // start a repeated timer that triggers timerAnimateOneFrame
        animateTimer = [NSTimer scheduledTimerWithTimeInterval:duration
                                                   target:self
                                                 selector:@selector(timerAnimateOneFrame)
                                                 userInfo:nil
                                                  repeats:YES];
    }
    lastDuration = duration;
}


- (NSTimeInterval)getDurationFromFile:(NSString*)gifFileName atFrame:(NSInteger)frame
{
    /* If the fps is "too fast" NSBitmapImageRep gives back a clamped value for slower fps and not the value from the file! WTF? */
    /*
    [gifRep setProperty:NSImageCurrentFrame withValue:@(frame)];
    NSTimeInterval currFrameDuration = [[gifRep valueForProperty: NSImageCurrentFrameDuration] floatValue];
    return currFrameDuration;
    */
    
    // As workaround for the problem of NSBitmapImageRep class we use CGImageSourceCopyPropertiesAtIndex that always gives back the real value
    CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) [NSURL URLWithString:gifFileName], NULL);
    if (source)
    {
        CFDictionaryRef cfdProperties = CGImageSourceCopyPropertiesAtIndex(source, frame, nil);
        NSDictionary *properties = CFBridgingRelease(cfdProperties);
        NSNumber *durationGIF = [[properties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                           objectForKey:(__bridge NSString *) kCGImagePropertyGIFUnclampedDelayTime];
        // Support of animated PNG start with macOS 10.10 and we can not use this API on lower systems.
        // Because of ths on lower systems a APNG will stand still like an normal PNG.
        NSNumber *durationPNG = 0;
        NSOperatingSystemVersion osVer = [[NSProcessInfo processInfo] operatingSystemVersion];
        if (osVer.majorVersion > 10 || osVer.minorVersion >= 10)
        {
            durationPNG = [[properties objectForKey:(__bridge NSString *)kCGImagePropertyPNGDictionary]
                                 objectForKey:(__bridge NSString *) kCGImagePropertyAPNGUnclampedDelayTime];
        }
        
        CFRelease(source);
        
        //scale duration by 1000 to get ms, because it is in sec and a fraction between 1 and 0
        NSInteger durMs = [durationGIF doubleValue] * 1000.0;
        // We want to catch the case that duration is 0ms (infinity fps!), because vale was not set in frame 0 frame of GIF
        if (durMs== 0)
        {
            // wenn NO duration was set it could be still an PNG file
            durMs = [durationPNG doubleValue] * 1000.0;
            if (durMs== 0)
            {
                // wenn NO duration was set, we use an default duration (60 fps)
                return 1/(MAX_FRAME_RATE*1.0);
            }
            else
            {
                // if we have a valid duration from an PNG than return it
                return [durationPNG doubleValue];
            }

        }
        else
        {
            // if we have a valid duration than return it
            return [durationGIF doubleValue];
        }
    }
    else
    {
        // if not even a file could be open, we use an default duration (60 fps)
        return 1/MAX_FRAME_RATE;
    }
}

- (void) drawAttributedStringGL:(NSAttributedString *)attributedString atPoint:(NSPoint)point
{
    NSSize texturSize = NSMakeSize(0.0f, 0.0f);
    NSSize frameSize = NSMakeSize(0.0f, 0.0f);
    
    frameSize = [attributedString size];
    NSImage * image = [[NSImage alloc] initWithSize:frameSize];
    [image lockFocus];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];
    [attributedString drawAtPoint:NSMakePoint (0.0f, 0.0f)];
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height)];
    [image unlockFocus];
    texturSize.width = [bitmap pixelsWide];
    texturSize.height = [bitmap pixelsHigh];
    NSRect bounds = NSMakeRect (point.x, point.y, texturSize.width, texturSize.height);
    
    [self drawImageGL:[bitmap bitmapData] pixelWidth:texturSize.width pixelHeight:texturSize.height withFilter:FILTER_OPT_BLUR hasAlpha:YES atRect:bounds];
}

- (void) drawImageGL:(void *)pixelsBytes pixelWidth:(NSInteger)width pixelHeight:(NSInteger)height withFilter:(NSInteger)filter hasAlpha: (Boolean)alpha atRect:(NSRect) rect
{
    glEnable(GL_TEXTURE_2D);
    if (alpha == TRUE) {
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    }
    
    //get one free texture name
    GLuint frameTextureName;
    glGenTextures(1, &frameTextureName);
    //bind a Texture object to the name
    glBindTexture(GL_TEXTURE_2D,frameTextureName);
    
    // set paramter for texture
    if (filter == FILTER_OPT_BLUR)
    {
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    }
    else if (filter == FILTER_OPT_SHARP)
    {
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    }
    else
    {
        // use sharp filter as default
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    }
    
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_RGBA,
                     (GLint)width,
                     (GLint)height,
                     0,
                     GL_RGBA,
                     GL_UNSIGNED_BYTE,
                     pixelsBytes
                     );
    
    // generate Mipmap
    glGenerateMipmap(GL_TEXTURE_2D);
    
    // define the target position of texture (related to screen defined by glOrtho) witch makes the texture visible
    float x = rect.origin.x;
    float y = rect.origin.y;
    float iheight = rect.size.height;
    float iwidth = rect.size.width;
    glBegin( GL_QUADS );
    glTexCoord2f( 0.f, 0.f ); glVertex2f(x, y); //Bottom left
    glTexCoord2f( 1.f, 0.f ); glVertex2f(x + iwidth, y); //Bottom right
    glTexCoord2f( 1.f, 1.f ); glVertex2f(x + iwidth, y + iheight); //Top right
    glTexCoord2f( 0.f, 1.f ); glVertex2f(x, y + iheight); //Top left
    glEnd();
    
    glDisable(GL_BLEND);
    glDisable(GL_TEXTURE_2D);
    
    glDeleteTextures(1,&frameTextureName);
}

- (void) animateNoGifGL
{
    [self startRenderGL:NO];
    
    // print an indication message
    NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
    if ([self isPreview])
    {
        [attribs setObject: [NSFont fontWithName: @"Helvetica" size: 14.0f] forKey: NSFontAttributeName];
    }
    else
    {
        [attribs setObject: [NSFont fontWithName: @"Helvetica" size: 34.0f] forKey: NSFontAttributeName];
    }
    [attribs setObject: [NSColor redColor] forKey: NSForegroundColorAttributeName];
    NSAttributedString *nogifAtStr = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"nogif",@"Localizable",[NSBundle bundleForClass:[self class]],nil) attributes:attribs];
    NSAttributedString *selectAtStr = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"select",@"Localizable",[NSBundle bundleForClass:[self class]],nil) attributes:attribs];
    [self drawAttributedStringGL:nogifAtStr atPoint:NSMakePoint (screenRect.size.width/2 - [nogifAtStr size].width/2, screenRect.size.height/4-[nogifAtStr size].height/2)];
    [self drawAttributedStringGL:selectAtStr atPoint:NSMakePoint (screenRect.size.width/2 - [selectAtStr size].width/2, screenRect.size.height/2-[selectAtStr size].height/2)];
    
    NSImage *iconImg = [[NSBundle bundleForClass:[self class]] imageForResource:@"thumbnail.tiff"];
    if (iconImg)
    {
        NSBitmapImageRep *iconRep = [NSBitmapImageRep imageRepWithData:[iconImg TIFFRepresentation]];
        if (iconRep)
        {
            NSSize iconSize;
            if ([self isPreview])
            {
                iconSize = NSMakeSize([iconRep size].width/2, [iconRep size].height/2);
            }
            else
            {
                iconSize = NSMakeSize([iconRep size].width*2, [iconRep size].height*2);
            }
            void *pixelDataIcon= [iconRep bitmapData];
            if (pixelDataIcon != NULL)
            {
                [self drawImageGL:pixelDataIcon pixelWidth: [iconRep pixelsWide] pixelHeight:[iconRep pixelsHigh] withFilter:FILTER_OPT_BLUR hasAlpha:[iconRep hasAlpha] atRect:NSMakeRect(screenRect.size.width/2 - iconSize.width/2, screenRect.size.height/4*3 - iconSize.height/2, iconSize.width, iconSize.height)];
            }
        }
    }
    
    [self endRenderGL];
}

- (void) animateWithGifGL
{
    [self startRenderGL:YES];
    
    void *pixelData=NULL;
    if (loadAnimationToMem == TRUE)
    {
        // we load bitmap data from memory and save CPU time (created during startAnimation)
        NSData *pixels = [animationImages objectAtIndex:currFrameCount];
        pixelData = (void*)[pixels bytes];
    }
    else
    {
        // bitmapData needs more CPU time to create bitmap data
        [imgRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
        pixelData = [imgRep bitmapData];
    }
    
    if (tiles == TILE_OPT_1)
    {
        // only draw one tile
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:targetRect];
    }
    else
    {
        // draw 9 tiles (3 by 3)
        NSRect r11 = NSMakeRect(targetRect.origin.x, targetRect.origin.y, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r21 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3, targetRect.origin.y, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r31 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3*2, targetRect.origin.y, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r12 = NSMakeRect(targetRect.origin.x, targetRect.origin.y+targetRect.size.height/3, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r22 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3, targetRect.origin.y+targetRect.size.height/3, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r32 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3*2, targetRect.origin.y+targetRect.size.height/3, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r13 = NSMakeRect(targetRect.origin.x, targetRect.origin.y+targetRect.size.height/3*2, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r23 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3, targetRect.origin.y+targetRect.size.height/3*2, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r33 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3*2, targetRect.origin.y+targetRect.size.height/3*2, targetRect.size.width/3, targetRect.size.height/3);
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r11];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r21];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r31];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r12];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r22];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r32];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r13];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r23];
        [self drawImageGL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r33];
    }
    
    [self endRenderGL];
}

- (void) startRenderGL:(BOOL)allowScale
{
    // change context to glview and clear screen to setup color
    [glView.openGLContext makeCurrentContext];
    glClearColor(backgrRed, backgrGreen, backgrBlue, GL_ALPHA_OPAQUE);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    glPushMatrix();
    
    if (allowScale == YES)
    {
        // scale the image by a given factor
        // scale only if needed
        if (viewOption==VIEW_OPT_SCALE_SIZE && (scale>1.1 || scale<0.9))
        {
            glScalef(scale, scale, 1.0);
        }
    }
    
    // defines the pixel resolution of the screen (can be smaller than real screen, but than you will see pixels)
    glOrtho(0,screenRect.size.width,screenRect.size.height,0,-1,1);
}

- (void) endRenderGL
{
    //End phase
    glPopMatrix();
    
    [glView.openGLContext flushBuffer]; // Swap Buffers and can only used after setting up OpenGL view with option NSOpenGLPFADoubleBuffer otherwise use glFlush()
}

- (void) drawAttributedStringMTL:(NSAttributedString *)attributedString atPoint:(NSPoint)point
{
    NSSize texturSize = NSMakeSize(0.0f, 0.0f);
    NSSize frameSize = NSMakeSize(0.0f, 0.0f);
    
    frameSize = [attributedString size];
    NSImage * image = [[NSImage alloc] initWithSize:frameSize];
    [image lockFocus];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];
    [attributedString drawAtPoint:NSMakePoint (0.0f, 0.0f)];
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height)];
    [image unlockFocus];
    texturSize.width = [bitmap pixelsWide];
    texturSize.height = [bitmap pixelsHigh];
    NSRect bounds = NSMakeRect (point.x, point.y, texturSize.width, texturSize.height);
    
    [self drawImageMTL:[bitmap bitmapData] pixelWidth:texturSize.width pixelHeight:texturSize.height withFilter:FILTER_OPT_BLUR hasAlpha:YES atRect:bounds];
}

- (void) drawImageMTL:(void *)pixelsBytes pixelWidth:(NSInteger)width pixelHeight:(NSInteger)height withFilter:(NSInteger)filter hasAlpha: (Boolean)alpha atRect:(NSRect) rect
{
    // TODO: use blitter to genereate mipmaps
    
    // update alpha blending depending on hasAlpha (in an GIF file not each frame uses alpha blending and it needs to be set for each frame individually)
    NSError *err = nil;
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = alpha;
    pipelineStateMTL = [deviceMTL newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&err];
    
    // add a quad where the texture will be mapped onto
    struct Vertex vertexArrayData[6] = {
        {.position={rect.origin.x+rect.size.width, rect.origin.y,                  0.0},.textCoord={1.0,0.0}}, // Top Right
        {.position={rect.origin.x,                 rect.origin.y,                  0.0},.textCoord={0.0,0.0}}, // Top Left
        {.position={rect.origin.x,                 rect.origin.y+rect.size.height, 0.0},.textCoord={0.0,1.0}}, // Bottom Left
        {.position={rect.origin.x+rect.size.width, rect.origin.y,                  0.0},.textCoord={1.0,0.0}}, // Top Right
        {.position={rect.origin.x,                 rect.origin.y+rect.size.height, 0.0},.textCoord={0.0,1.0}}, // Bottom Left
        {.position={rect.origin.x+rect.size.width, rect.origin.y+rect.size.height, 0.0},.textCoord={1.0,1.0}}  // Bottom Right
    };

    id <MTLBuffer> vertexArray = [deviceMTL newBufferWithBytes: vertexArrayData length: sizeof(vertexArrayData) options: MTLResourceStorageModeManaged];
    [renderMTL setVertexBuffer: vertexArray offset: 0 atIndex: 0];
    
    // add a sampler (could be also donde direct in the GPU Shader code)
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    // set paramter for texture
    if (filter == FILTER_OPT_BLUR)
    {
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    }
    else if (filter == FILTER_OPT_SHARP)
    {
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
    }
    else
    {
        // use sharp filter as default
        samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
        samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
    }
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    id<MTLSamplerState> sampler = [deviceMTL newSamplerStateWithDescriptor:samplerDescriptor];
    [renderMTL setFragmentSamplerState:sampler atIndex:0];

    // add the texture
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:YES];
    id<MTLTexture> texture = [deviceMTL newTextureWithDescriptor:textureDescriptor];
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [texture replaceRegion:region mipmapLevel:0 withBytes:pixelsBytes bytesPerRow:width*SIZE_OF_BGRA_PIXEL];
    [renderMTL setFragmentTexture:texture atIndex:0];
    
    // needs to be called after vertex, sampler and texture
    [renderMTL drawPrimitives: MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

- (void) animateNoGifMTL
{
    [self startRenderMTL:NO];
    
    NSMutableDictionary *attribs = [NSMutableDictionary dictionary];
    if ([self isPreview])
    {
        [attribs setObject: [NSFont fontWithName: @"Helvetica" size: 14.0f] forKey: NSFontAttributeName];
    }
    else
    {
        [attribs setObject: [NSFont fontWithName: @"Helvetica" size: 34.0f] forKey: NSFontAttributeName];
    }
    [attribs setObject: [NSColor redColor] forKey: NSForegroundColorAttributeName];
    NSAttributedString *nogifAtStr = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"nogif",@"Localizable",[NSBundle bundleForClass:[self class]],nil) attributes:attribs];
    NSAttributedString *selectAtStr = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTableInBundle(@"select",@"Localizable",[NSBundle bundleForClass:[self class]],nil) attributes:attribs];
    [self drawAttributedStringMTL:nogifAtStr atPoint:NSMakePoint (screenRect.size.width/2 - [nogifAtStr size].width/2, screenRect.size.height/4-[nogifAtStr size].height/2)];
    [self drawAttributedStringMTL:selectAtStr atPoint:NSMakePoint (screenRect.size.width/2 - [selectAtStr size].width/2, screenRect.size.height/2-[selectAtStr size].height/2)];
    
    NSImage *iconImg = [[NSBundle bundleForClass:[self class]] imageForResource:@"thumbnail.tiff"];
    if (iconImg)
    {
        NSBitmapImageRep *iconRep = [NSBitmapImageRep imageRepWithData:[iconImg TIFFRepresentation]];
        if (iconRep)
        {
            NSSize iconSize;
            if ([self isPreview])
            {
                iconSize = NSMakeSize([iconRep size].width/2, [iconRep size].height/2);
            }
            else
            {
                iconSize = NSMakeSize([iconRep size].width*2, [iconRep size].height*2);
            }
            void *pixelDataIcon= [iconRep bitmapData];
            if (pixelDataIcon != NULL)
            {
                [self drawImageMTL:pixelDataIcon pixelWidth: [iconRep pixelsWide] pixelHeight:[iconRep pixelsHigh] withFilter:FILTER_OPT_BLUR hasAlpha:[iconRep hasAlpha] atRect:NSMakeRect(screenRect.size.width/2 - iconSize.width/2, screenRect.size.height/4*3 - iconSize.height/2, iconSize.width, iconSize.height)];
            }
        }
    }
    
    [self endRenderMTL];
}

- (void) animateWithGifMTL
{
    [self startRenderMTL:YES];
    
    void *pixelData=NULL;
    if (loadAnimationToMem == TRUE)
    {
        // we load bitmap data from memory and save CPU time (created during startAnimation)
        NSData *pixels = [animationImages objectAtIndex:currFrameCount];
        pixelData = (void*)[pixels bytes];
    }
    else
    {
        // bitmapData needs more CPU time to create bitmap data
        [imgRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
        pixelData = [imgRep bitmapData];
    }
    
    if (tiles == TILE_OPT_1)
    {
        // only draw one tile
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:targetRect];
    }
    else
    {
        // draw 9 tiles (3 by 3)
        NSRect r11 = NSMakeRect(targetRect.origin.x, targetRect.origin.y, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r21 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3, targetRect.origin.y, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r31 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3*2, targetRect.origin.y, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r12 = NSMakeRect(targetRect.origin.x, targetRect.origin.y+targetRect.size.height/3, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r22 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3, targetRect.origin.y+targetRect.size.height/3, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r32 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3*2, targetRect.origin.y+targetRect.size.height/3, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r13 = NSMakeRect(targetRect.origin.x, targetRect.origin.y+targetRect.size.height/3*2, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r23 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3, targetRect.origin.y+targetRect.size.height/3*2, targetRect.size.width/3, targetRect.size.height/3);
        NSRect r33 = NSMakeRect(targetRect.origin.x+targetRect.size.width/3*2, targetRect.origin.y+targetRect.size.height/3*2, targetRect.size.width/3, targetRect.size.height/3);
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r11];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r21];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r31];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r12];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r22];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r32];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r13];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r23];
        [self drawImageMTL:pixelData pixelWidth: [imgRep pixelsWide] pixelHeight:[imgRep pixelsHigh] withFilter:filter hasAlpha:[imgRep hasAlpha] atRect:r33];
    }
    
    [self endRenderMTL];
}

- (void) startRenderMTL:(BOOL)allowScale
{
    uniforms_t uniforms;
    vector_float4 scale4 = {1.0,1.0,1.0,1.0}; // default scale is 1.0 and that means no scaling at all
    
    if (allowScale == YES)
    {
        // scale the image by a given factor
        // scale only if needed
        if (viewOption==VIEW_OPT_SCALE_SIZE && (scale>1.1 || scale<0.9))
        {
            scale4.x = scale;
            scale4.y = scale;
            scale4.z = scale;
        }
    }
    uniforms.scale = scale4;
    
    //  Get an available CommandBuffer
    commandBufferMTL = [commandQueueMTL commandBuffer];
    
    /* Thoughts on double and triple buffering in Metal:
       The Metal render code is only single buffered at the moment and needs to be changed to double buffer like OpenGL render code:
        -> at the moment is the missing double buffering is no problem and all runs smooth even vor 60 fps
        -> seems the buffering is handled by MTKView automaticly by setting preferredFramesPerSecond and getting an currentDrawable. But documentation and Internet are not quite exact about this.
        -> explicit setup of the number of used buffers is only possible by using "CAMetalLayer" and setting up "maximumDrawableCount" between 1 and 3. MTKView seems to encapsulate CAMetalLayer and so it can't setup directly with MTKView. -> Since I like the similarity between MTKView and NSOpenGLView I let it for the moment and don't change this. Maybe in the futre I will try this.
     */
    
    //  Get this frame’s target drawable
    drawableMTL = [mtlView currentDrawable];
    
    //  Configure the Color0 Attachment
    MTLRenderPassDescriptor *renderDesc = [MTLRenderPassDescriptor new];
    renderDesc.colorAttachments[0].texture = drawableMTL.texture;
    renderDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderDesc.colorAttachments[0].clearColor = MTLClearColorMake(backgrRed,backgrGreen,backgrBlue,1.0);
    
    //  Start a Render command
    renderMTL = [commandBufferMTL renderCommandEncoderWithDescriptor: renderDesc];
    [renderMTL setRenderPipelineState: pipelineStateMTL];
    
    // add a projection matrix with screen coordinates so that we can define our vertex-positions relativ to it (equivalent to glOrtho)
    // vertexes with an screen coordinates(0,0,width,height) will be than convertet in vertex shader of GPU into vertexes
    // with the Metal Normalized Coordinates (-1,0,1)
    // as GPU needs it for furter computing
    uniforms.projection = matrix_ortho(0, screenRect.size.width, screenRect.size.height, 0, 0, 1);
    
    // add uniforms data (at the moment scale factor and projection matrix)
    [renderMTL setVertexBytes:&uniforms length:sizeof(uniforms_t) atIndex:1];
}

- (void) endRenderMTL
{
    // encode the defined renderer
    [renderMTL endEncoding];
    
    // Tell CoreAnimation when to present this drawable 
    [commandBufferMTL presentDrawable:drawableMTL];
    
    // Put the command buffer into the queue
    [commandBufferMTL commit];
    
    // direct call of draw from MTKView after finishing of rendering avoids the console logs:
    // "[CAMetalLayerDrawable texture] should not be called after already presenting this drawable. Get a nextDrawable instead."
    // "[CAMetalLayerDrawable present] should not be called after already presenting this drawable. Get a nextDrawable instead."
    [mtlView draw];
}

@end
