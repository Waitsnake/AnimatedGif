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
    trigByTimer = FALSE;
    currFrameCount = FRAME_COUNT_NOT_USED;
    self = [super initWithFrame:frame isPreview:isPreview];
    
    // initialize screensaver defaults with an default value
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                 @"file:///please/select/an/gif/animation.gif", @"GifFileName", @"30.0", @"GifFrameRate", @"NO", @"GifFrameRateManual", @"0", @"ViewOpt", @"4", @"ScaleOpt", @"1", @"FilterOpt", @"0", @"TileOpt", @"0.0", @"BackgrRed", @"0.0", @"BackgrGreen", @"0.0", @"BackgrBlue", @"NO", @"LoadAniToMem", @"5", @"ChangeInterval",nil]];
    
    if (self) {
        self.glView = [self createGLView];
        [self setAnimationTimeInterval:DEFAULT_ANIME_TIME_INTER];
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

- (NSOpenGLView *)createGLView
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

- (void) drawRect:(NSRect)rect
{
    // not needed since we use animateOneFrame() and left empty so that super method of NSView is not called to save same CPU time
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self.glView setFrameSize:newSize];
}

- (BOOL)isOpaque
{
    // this keeps Cocoa from unnecessarily redrawing our superview
    return YES;
}

- (void)dealloc
{
    [self.glView removeFromSuperview];
    self.glView = nil;
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
        
        [self addSubview:self.glView];
        
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
    float frameRate = [defaults floatForKey:@"GifFrameRate"];
    BOOL frameRateManual = [defaults boolForKey:@"GifFrameRateManual"];
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
    NSString *newGifFileName = [self getRandomGifFile:gifFileName];
    
    // load GIF image
    BOOL isFileLoaded = [self loadGifFromFile:newGifFileName andUseManualFps:frameRateManual withFps:frameRate];
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
        [NSTimer scheduledTimerWithTimeInterval:(changeIntervalInMin * 60)
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
                                                             object: NULL];
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
    }
    
    if (loadAnimationToMem == TRUE)
    {
        /*clean all pre-calculated bitmap images*/
        [animationImages removeAllObjects];
        animationImages = nil;
    }
    img = nil;
    currFrameCount = FRAME_COUNT_NOT_USED;
}

- (void)animateOneFrame
{

    if (currFrameCount == FRAME_COUNT_NOT_USED)
    {
        // FRAME_COUNT_NOT_USED means no image is loaded and so we clear the screen with the set background color and print an indication message
        
        // only clear screen with background color (OpenGL)
        [self.glView.openGLContext makeCurrentContext];
        glClearColor(backgrRed, backgrGreen, backgrBlue, GL_ALPHA_OPAQUE);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        // print an indication message
        glPushMatrix();
        glOrtho(0,screenRect.size.width,screenRect.size.height,0,-1,1);
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
        [self drawAttributedString:nogifAtStr atPoint:NSMakePoint (screenRect.size.width/2 - [nogifAtStr size].width/2, screenRect.size.height/4-[nogifAtStr size].height/2)];
        [self drawAttributedString:selectAtStr atPoint:NSMakePoint (screenRect.size.width/2 - [selectAtStr size].width/2, screenRect.size.height/2-[selectAtStr size].height/2)];
        
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
                void *pixelDataIcon= [iconRep bitmapData];;
                if (pixelDataIcon != NULL)
                {
                    [self drawImage:pixelDataIcon pixelWidth: [iconRep pixelsWide] pixelHeight:[iconRep pixelsHigh] hasAlpha:[iconRep hasAlpha] atRect:NSMakeRect(screenRect.size.width/2 - iconSize.width/2, screenRect.size.height/4*3 - iconSize.height/2, iconSize.width, iconSize.height)];
                }
            }
        }
        
        glPopMatrix();
        
        [self.glView.openGLContext flushBuffer]; // Swap Buffers and can only used after setting up OpenGL view with option NSOpenGLPFADoubleBuffer otherwise use glFlush()
        
    }
    else
    {
        // draw the selected frame


        // change context to glview
        [self.glView.openGLContext makeCurrentContext];
            
        // first clear screen with background color
        glClearColor(backgrRed, backgrGreen, backgrBlue, GL_ALPHA_OPAQUE);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
            
        // Start phase
        glPushMatrix();
        
        // scale the image by a given factor
        // scale only if needed
        if (viewOption==VIEW_OPT_SCALE_SIZE && (scale>1.1 || scale<0.9))
        {
            glScalef(scale, scale, 1.0);
        }
        
        // defines the pixel resolution of the screen (can be smaller than real screen, but than you will see pixels)
        glOrtho(0,screenRect.size.width,screenRect.size.height,0,-1,1);
        
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
            [gifRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
            pixelData = [gifRep bitmapData];
        }
            
        if (tiles == TILE_OPT_1)
        {
            // only draw one tile
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:targetRect];
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
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r11];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r21];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r31];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r12];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r22];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r32];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r13];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r23];
            [self drawImage:pixelData pixelWidth: [gifRep pixelsWide] pixelHeight:[gifRep pixelsHigh] hasAlpha:[gifRep hasAlpha] atRect:r33];
        }
            
        //End phase
        glPopMatrix();
        
        [self.glView.openGLContext flushBuffer]; // Swap Buffers and can only used after setting up OpenGL view with option NSOpenGLPFADoubleBuffer otherwise use glFlush()
    
        //calculate next frame of GIF to show
        if (currFrameCount < maxFrameCount-1)
        {
            currFrameCount++;
        }
        else
        {
            currFrameCount = FIRST_FRAME;
        }
    }
    
    return;
}

-(IBAction)aboutClick:(id)sender {
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
    if (!_aboutWindowController)
        _aboutWindowController = [[NSWindowController alloc] initWithWindow:self.aboutWindow];
    
    // Show window
    if (_aboutWindowController) [_aboutWindowController showWindow:self];
    // unfortunately the modal not longer works since 10.14 and crashes the whole app
    //[NSApp runModalForWindow:self.aboutWindow];
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
        NSTimeInterval duration = [self getDurationFromGifFile:gifFileName];
        float fps = 1/duration;
        [self.labelFpsGif setStringValue:[NSString stringWithFormat:@"%2.1f", fps]];
        [self hideFpsFromFile:NO];
        
        // disable time interval slider in case an file is selected
        [self enableSliderChangeInterval:NO];
    }
    
    
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
    
    [openDlg close];
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
    
    [openDlg close];
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
    
    if (!openDlg) openDlg = [NSOpenPanel openPanel];
    
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
    [openDlg setAllowedFileTypes:[[NSArray alloc] initWithObjects:@"gif", @"GIF", nil]];
    
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
                NSTimeInterval duration = [self getDurationFromGifFile:[NSURL URLWithString:newSelectedFileOrDir.absoluteString].absoluteString];
                float fps = 1/duration;
                [self.labelFpsGif setStringValue:[NSString stringWithFormat:@"%2.1f", fps]];
                [self hideFpsFromFile:NO];
                
                // disable time interval slider only in case that an file is selected
                [self enableSliderChangeInterval:NO];
            }
            
        }
        else if (result== NSModalResponseCancel)
        {
            //do nothing
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
    NSDictionary *cfg  = @{@"Label":@"com.waitsnake.animatedgif", @"ProgramArguments":@[pathToScreenSaverEngine,@"-window"], @"KeepAlive":@{@"OtherJobEnabled":@{@"com.apple.SystemUIServer.agent":@YES,@"com.apple.Finder":@YES,@"com.apple.Dock.agent":@YES}}, @"ThrottleInterval":@0};
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
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == 'gif'"];
            
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

- (BOOL)loadGifFromFile:(NSString*)gifFileName andUseManualFps: (BOOL)manualFpsActive withFps: (float)fps;
{
    // load the GIF
    img = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:gifFileName]];
    
    // check if a GIF was loaded
    if (img)
    {
        // get an NSBitmapImageRep that we need to get to the bitmap data and properties of GIF
        gifRep = (NSBitmapImageRep *)[[img representations] objectAtIndex:FIRST_FRAME];
        // get max number of frames of GIF
        maxFrameCount = [[gifRep valueForProperty: NSImageFrameCount] integerValue];
        
        // setup FPS of loaded GIF
        if(manualFpsActive)
        {
            // set frame rate manual
            [self setAnimationTimeInterval:1/fps];
        }
        else
        {
            // set frame duration from data from gif file
            NSTimeInterval duration = [self getDurationFromGifFile:gifFileName];
            [self setAnimationTimeInterval:duration];
        }
        
        // in case of no review mode and active config option create an array in memory with all frames of bitmap in bitmap format (can be used directly as OpenGL texture)
        if (loadAnimationToMem == TRUE)
        {
            animationImages = [[NSMutableArray alloc] init];
            for(NSUInteger frame=0;frame<maxFrameCount;frame++)
            {
                [gifRep setProperty:NSImageCurrentFrame withValue:@(frame)];
                // bitmapData needs most CPU time during animation.
                // thats why we execute bitmapData here during startAnimation and not in animateOneFrame. the start of screensaver will be than slower of cause, but during animation itself we need less CPU time
                unsigned char *data = [gifRep bitmapData];
                unsigned long size = [gifRep bytesPerPlane]*sizeof(unsigned char);
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

- (NSTimeInterval)getDurationFromGifFile:(NSString*)gifFileName
{
    /* If the fps is "too fast" NSBitmapImageRep gives back a clamped value for slower fps and not the value from the file! WTF? */
    /*
    [gifRep setProperty:NSImageCurrentFrame withValue:@(2)];
    NSTimeInterval currFrameDuration = [[gifRep valueForProperty: NSImageCurrentFrameDuration] floatValue];
    return currFrameDuration;
    */
    
    // As workaround for the problem of NSBitmapImageRep class we use CGImageSourceCopyPropertiesAtIndex that always gives back the real value
    CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) [NSURL URLWithString:gifFileName], NULL);
    if (source)
    {
        CFDictionaryRef cfdProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
        NSDictionary *properties = CFBridgingRelease(cfdProperties);
        NSNumber *duration = [[properties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                           objectForKey:(__bridge NSString *) kCGImagePropertyGIFUnclampedDelayTime];
        
        CFRelease(source);
        
        //scale duration by 1000 to get ms, because it is in sec and a fraction between 1 and 0
        NSInteger durMs = [duration doubleValue] * 1000.0;
        // We want to catch the case that duration is 0ms (infinity fps!), because vale was not set in frame 0 frame of GIF
        if (durMs== 0)
        {
            // wenn NO duration was set, we use an default duration (15 fps)
            return DEFAULT_ANIME_TIME_INTER;
        }
        else
        {
            // if we have a valid duration than return it
            return [duration doubleValue];
        }
    }
    else
    {
        // if not even a GIF file could be open, we use an default duration (15 fps)
        return DEFAULT_ANIME_TIME_INTER;
    }
}

- (void) drawAttributedString:(NSAttributedString *)attributedString atPoint:(NSPoint)point
{
    GLuint texturName = 0;
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
    
    glPushAttrib(GL_TEXTURE_BIT);
    glGenTextures (1, &texturName);
    glBindTexture (GL_TEXTURE_RECTANGLE_EXT, texturName);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA, texturSize.width, texturSize.height, 0, [bitmap hasAlpha] ? GL_RGBA : GL_RGB, GL_UNSIGNED_BYTE, [bitmap bitmapData]);
    glPopAttrib();
    
    glPushAttrib(GL_ENABLE_BIT | GL_TEXTURE_BIT | GL_COLOR_BUFFER_BIT);
    glDisable (GL_DEPTH_TEST);
    glEnable (GL_BLEND);
    glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable (GL_TEXTURE_RECTANGLE_EXT);
    glBindTexture (GL_TEXTURE_RECTANGLE_EXT, texturName);
    glBegin (GL_QUADS);
    glTexCoord2f (0.0f, 0.0f); glVertex2f (bounds.origin.x, bounds.origin.y);
    glTexCoord2f (0.0f, texturSize.height); glVertex2f (bounds.origin.x, bounds.origin.y + bounds.size.height);
    glTexCoord2f (texturSize.width, texturSize.height); glVertex2f (bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height);
    glTexCoord2f (texturSize.width, 0.0f); glVertex2f (bounds.origin.x + bounds.size.width, bounds.origin.y);
    glEnd ();
    glPopAttrib();
    glDeleteTextures(1,&texturName);
}

- (void) drawImage:(void *)pixelsBytes pixelWidth:(NSInteger)width pixelHeight:(NSInteger)height  hasAlpha: (Boolean)alpha atRect:(NSRect) rect
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
        // use blur filter as default
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
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

@end
