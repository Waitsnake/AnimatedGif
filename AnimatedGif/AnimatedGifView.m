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
                                 @"file:///please/select/an/gif/animation.gif", @"GifFileName", @"30.0", @"GifFrameRate", @"NO", @"GifFrameRateManual", @"0", @"ViewOpt", @"0.0", @"BackgrRed", @"0.0", @"BackgrGreen", @"0.0", @"BackgrBlue", @"NO", @"LoadAniToMem", @"5", @"ChangeInterval",nil]];
    
    if (self) {
        self.glView = [self createGLView];
        [self setAnimationTimeInterval:DEFAULT_ANIME_TIME_INTER];
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

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self.glView setFrameSize:newSize];
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

- (void) receiveWakeNote: (NSNotification*) note
{
    // Event is fired after return from sleep.
    
    // Simply kill screensaverengine. If it was in background mode the launchd should restart the screensaver in background mode. It is a bit hard but works until I found a cleaner way to restore the glview that stays white.
    NSString *cmdstr = [[NSString alloc] initWithFormat:@"%@", @"killall ScreenSaverEngine"];
    system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
    
}

- (void)startAnimation
{
    if (trigByTimer == FALSE)
    {
        // only call super method in case startAnimation is not called by timerMethod
        [super startAnimation];
        
        // Fix for the issue that after starting screensaver in background mode a second instance of a screensaver will not start(e.g. after inactivity of user or moving mouse to an active corner). Calling screensaverenginge with parameter -idlecheck will enable a second screensaver instance.
        NSString *cmdstr = [[NSString alloc] initWithFormat:@"%@", @"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -idleCheck"];
        system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
        
        // Fix for issue that glview is not working(stay white) after return from sleep. Register for event that is fired after return from sleep.
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                               selector: @selector(receiveWakeNote:)
                                                                   name: NSWorkspaceDidWakeNotification object: NULL];
    }
    
    // get filename from screensaver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    NSString *gifFileName = [defaults objectForKey:@"GifFileName"];
    float frameRate = [defaults floatForKey:@"GifFrameRate"];
    BOOL frameRateManual = [defaults boolForKey:@"GifFrameRateManual"];
    loadAnimationToMem = [defaults boolForKey:@"LoadAniToMem"];
    viewOption = [defaults integerForKey:@"ViewOpt"];
    backgrRed = [defaults floatForKey:@"BackgrRed"];
    backgrGreen = [defaults floatForKey:@"BackgrGreen"];
    backgrBlue = [defaults floatForKey:@"BackgrBlue"];
    NSInteger changeIntervalInSec = [defaults integerForKey:@"ChangeInterval"] * 60;
    BOOL isADir = [self isDir:gifFileName];

    // check if it is a file or a directory
    if (isADir)
    {
        // select a random file from directory
        gifFileName = [self getRandomGifFile:gifFileName];

    }
    
    // load GIF image
    img = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:gifFileName]];
    if (img)
    {
        gifRep = (NSBitmapImageRep *)[[img representations] objectAtIndex:FIRST_FRAME];
        maxFrameCount = [[gifRep valueForProperty: NSImageFrameCount] integerValue];
        currFrameCount = FIRST_FRAME;
        
        if(frameRateManual)
        {
            // set frame rate manual
            [self setAnimationTimeInterval:1/frameRate];
        }
        else
        {
            // set frame duration from data from gif file
            /* If the fps is "too fast" NSBitmapImageRep gives back a clamped value for slower fps and not the value from the file! WTF? */
            /*
            [gifRep setProperty:NSImageCurrentFrame withValue:@(2)];
            float currFrameDuration = [[gifRep valueForProperty: NSImageCurrentFrameDuration] floatValue];
            [self setAnimationTimeInterval:currFrameDuration];
             */
            
            // As workaround for the problem of NSBitmapImageRep class we use CGImageSourceCopyPropertiesAtIndex that always gives back the real value
            CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) [NSURL URLWithString:gifFileName], NULL);
            if (source)
            {
                CFDictionaryRef cfdProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
                NSDictionary *properties = CFBridgingRelease(cfdProperties);
                float duration = [[[properties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                               objectForKey:(__bridge NSString *) kCGImagePropertyGIFUnclampedDelayTime] doubleValue];
                CFRelease(source);
                [self setAnimationTimeInterval:duration];
            }
            else
            {
                [self setAnimationTimeInterval:DEFAULT_ANIME_TIME_INTER];
            }
        }
        
        // add glview to screensaver view in case of not in preview mode
        if ([self isPreview] == FALSE)
        {
            [self addSubview:self.glView];
        }
        
        // in case of no review mode and active config option create an array in memory with all frames of bitmap in bitmap format (can be used directly as OpenGL texture)
        if (   ([self isPreview] == FALSE)
            && (loadAnimationToMem == TRUE)
           )
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
        
    }
    else
    {
        currFrameCount = FRAME_COUNT_NOT_USED;
    }
    
    // check if it is a file or a directory
    if (isADir)
    {

        // start a one-time timer at end of startAnimation otherwise the GIF loading times are part of timer
        [NSTimer scheduledTimerWithTimeInterval:changeIntervalInSec
                                         target:self
                                       selector:@selector(timerMethod)
                                       userInfo:nil
                                        repeats:NO];
    }
}

- (void)stopAnimation
{
    if (trigByTimer == FALSE)
    {
        // only call super method in case stopAnimation is not called by timerMethod
        [super stopAnimation];

        // only remove GL view in case stopAnimation is not called by timerMethod
        if ([self isPreview] == FALSE)
        {
            // remove glview from screensaver view
            [self removeFromSuperview];
        }
    }
    
    if (   ([self isPreview] == FALSE)
        && (loadAnimationToMem == TRUE))
    {
        /*clean all pre-calculated bitmap images*/
        [animationImages removeAllObjects];
        animationImages = nil;
    }
    img = nil;
    currFrameCount = FRAME_COUNT_NOT_USED;
}

- (BOOL)isOpaque
{
    // this keeps Cocoa from unnecessarily redrawing our superview
    return YES;
}

- (void)animateOneFrame
{
    // set some values screensaver and GIF image size
    NSRect mainScreenRect = [[NSScreen mainScreen] frame];
    NSRect screenRect = [self bounds];
    NSRect target = screenRect;
    float screenRatio = [self pictureRatioFromWidth:screenRect.size.width andHeight:screenRect.size.height];
    float imgRatio = [self pictureRatioFromWidth:img.size.width andHeight:img.size.height];
    CGFloat scaledHeight;
    CGFloat scaledWidth;
    
    if (viewOption==VIEW_OPT_STRETCH_OPTIMAL)
    {
        // fit image optimal to screen
        if (imgRatio >= screenRatio)
        {
            target.size.height = [self calcHeightFromRatio:imgRatio andWidth:screenRect.size.width];
            target.origin.y = (screenRect.size.height - target.size.height)/2;
            target.size.width = screenRect.size.width;
            target.origin.x = screenRect.origin.x;
        }
        else
        {
            target.size.width = [self calcWidthFromRatio:imgRatio andHeight:screenRect.size.height];
            target.origin.x = (screenRect.size.width - target.size.width)/2;
            target.size.height = screenRect.size.height;
            target.origin.y = screenRect.origin.y;
        }
    }
    else if (viewOption==VIEW_OPT_STRETCH_MAXIMAL)
    {
        // stretch image maximal to screen
        target = screenRect;
    }
    else if (viewOption==VIEW_OPT_KEEP_ORIG_SIZE)
    {
        if ([self isPreview] == FALSE)
        {
            // in case of NO preview mode: simply keep original size of image
            target.size.height = img.size.height;
            target.size.width = img.size.width;
            target.origin.y = (screenRect.size.height - img.size.height)/2;
            target.origin.x = (screenRect.size.width - img.size.width)/2;
        }
        else
        {
            // in case of preview mode: we also need to calculate the ratio between the size of the physical main screen and the size of the preview window to scale the image down.
            scaledHeight = screenRect.size.height / mainScreenRect.size.height * img.size.height;
            scaledWidth = screenRect.size.width / mainScreenRect.size.width * img.size.width;
            target.size.height = scaledHeight;
            target.size.width = scaledWidth;
            target.origin.y = (screenRect.size.height - scaledHeight)/2;
            target.origin.x = (screenRect.size.width - scaledWidth)/2;
        }
    }
    else if (viewOption==VIEW_OPT_STRETCH_SMALL_SIDE)
    {
        // stretch image to smallest side
        if (imgRatio >= screenRatio)
        {
            target.size.height = screenRect.size.height;
            target.origin.y = screenRect.origin.y;
            target.size.width = [self calcWidthFromRatio:imgRatio andHeight:screenRect.size.height];
            target.origin.x = -1*(target.size.width - screenRect.size.width)/2;
        }
        else
        {
            target.size.width = screenRect.size.width;
            target.origin.x = screenRect.origin.x;
            target.size.height = [self calcHeightFromRatio:imgRatio andWidth:screenRect.size.width];
            target.origin.y = -1*(target.size.height - screenRect.size.height)/2;
        }
    }
    else
    {
        /*default is VIEW_OPT_STRETCH_MAXIMAL*/
        // stretch image maximal to screen
        target = screenRect;
    }
    
    if (currFrameCount == FRAME_COUNT_NOT_USED)
    {
        if ([self isPreview] == TRUE)
        {
            // only clear screen with background color (not OpenGL)
            [[NSColor colorWithDeviceRed: backgrRed green: backgrGreen blue: backgrBlue alpha: NS_ALPHA_OPAQUE] set];
            [NSBezierPath fillRect: screenRect];
        }
        else
        {
            // only clear screen with background color (OpenGL)
            [self.glView.openGLContext makeCurrentContext];
            glClearColor(backgrRed, backgrGreen, backgrBlue, GL_ALPHA_OPAQUE);
            glClear(GL_COLOR_BUFFER_BIT);
            glFlush();
            [self setNeedsDisplay:YES];
        }
    }
    else
    {
            
        // draw the selected frame
        if ([self isPreview] == TRUE)
        {
            
            // In Preview Mode OpenGL leads to crashes (?) so we make a classical image draw
            
            //select current frame from GIF (Hint: gifRep is a sub-object from img)
            [gifRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
            
            // than clear screen with background color
            [[NSColor colorWithDeviceRed: backgrRed green: backgrGreen blue: backgrBlue alpha: NS_ALPHA_OPAQUE] set];
            [NSBezierPath fillRect: screenRect];
            
            // now draw frame
            [img drawInRect:target];

        }
        else
        {
            // if we have no Preview Mode we use OpenGL to draw

            // change context to glview
            [self.glView.openGLContext makeCurrentContext];
            
            // first clear screen with background color
            glClearColor(backgrRed, backgrGreen, backgrBlue, GL_ALPHA_OPAQUE);
            glClear(GL_COLOR_BUFFER_BIT);
            
            // Start phase
            glPushMatrix();
            
            // defines the pixel resolution of the screen (can be smaller than real screen, but than you will see pixels)
            glOrtho(0,screenRect.size.width,screenRect.size.height,0,-1,1);
            
            glEnable(GL_TEXTURE_2D);
            if ([gifRep hasAlpha] == TRUE) {
                glEnable(GL_BLEND);
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            }
            
            //get one free texture name
            GLuint frameTextureName;
            glGenTextures(1, &frameTextureName);
            
            //bind a Texture object to the name
            glBindTexture(GL_TEXTURE_2D,frameTextureName);
            
            // load current bitmap as texture into the GPU
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            if (loadAnimationToMem == TRUE)
            {
                // we load bitmap data from memory and save CPU time (created during startAnimation)
                NSData *pixels = [animationImages objectAtIndex:currFrameCount];
                glTexImage2D(GL_TEXTURE_2D,
                         0,
                         GL_RGBA,
                         (GLint)[gifRep pixelsWide],
                         (GLint)[gifRep pixelsHigh],
                         0,
                         GL_RGBA,
                         GL_UNSIGNED_BYTE, 
                         [pixels bytes]
                         );
            }
            else
            {
                // bitmapData needs more CPU time to create bitmap data
                [gifRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
                glTexImage2D(GL_TEXTURE_2D,
                             0,
                             GL_RGBA,
                             (GLint)[gifRep pixelsWide],
                             (GLint)[gifRep pixelsHigh],
                             0,
                             GL_RGBA,
                             GL_UNSIGNED_BYTE,
                             [gifRep bitmapData]
                             );
            }
            
            glGenerateMipmap(GL_TEXTURE_2D);
            
            // define the target position of texture (related to screen defined by glOrtho) witch makes the texture visible
            float x = target.origin.x;
            float y = target.origin.y;
            float iheight = target.size.height;
            float iwidth = target.size.width;
            glBegin( GL_QUADS );
            glTexCoord2f( 0.f, 0.f ); glVertex2f(x, y); //Bottom left
            glTexCoord2f( 1.f, 0.f ); glVertex2f(x + iwidth, y); //Bottom right
            glTexCoord2f( 1.f, 1.f ); glVertex2f(x + iwidth, y + iheight); //Top right
            glTexCoord2f( 0.f, 1.f ); glVertex2f(x, y + iheight); //Top left
            glEnd();
            
            glDisable(GL_BLEND);
            glDisable(GL_TEXTURE_2D);
            
            //End phase
            glPopMatrix();
            
            //free texture object by name
            glDeleteTextures(1,&frameTextureName);
            
            glFlush();
            
            [self.glView.openGLContext flushBuffer];
            
            [self setNeedsDisplay:YES];
            
            // we change the window level only, if not in preview mode and if the level is already set by the ScreenSaverEngine to desktop level or lower. This allows the screensaver to be used in normal mode, when a screensaver is on the highest window level and not in background
            if (self.window.level <= kCGDesktopWindowLevel) {
                //  set the window level to desktop level, that fixes the problem that after an mission control switch the window is hided. because ScreenSaverEngine set the window level one step to low (kCGDesktopWindowLevel-1) to work correct with mission control that requires exactly kCGDesktopWindowLevel.
                [self.window setLevel:kCGDesktopWindowLevel];
            }
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
    }
    
    return;
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
    NSInteger changeInter = [defaults integerForKey:@"ChangeInterval"];
    
    // in the rarely case of an invalid value from default file we set an valid option
    if (viewOpt > MAX_VIEW_OPT)
    {
        viewOpt = VIEW_OPT_STRETCH_OPTIMAL;
    }
    
    if ([self isDir:gifFileName])
    {
        // if we have an directory an fps value for a file makes not much sense
        // we could calculate it for an randomly selected file but this would make thinks to complex
        [self.labelFpsGif setStringValue:@"(dir)"];
        [self hideFpsFromFile:YES];
        
        // enable time interval slider only in case that an directory is selected
        [self enableSliderChangeInterval:YES];
    }
    else
    {
        // set file fps in GUI
        CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) [NSURL URLWithString:gifFileName], NULL);
        if (source)
        {
            CFDictionaryRef cfdProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
            NSDictionary *properties = CFBridgingRelease(cfdProperties);
            float duration = [[[properties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                               objectForKey:(__bridge NSString *) kCGImagePropertyGIFUnclampedDelayTime] doubleValue];
            CFRelease(source);
            float fps = 1/duration;
            
            [self.labelFpsGif setStringValue:[NSString stringWithFormat:@"%2.1f", fps]];
        }
        else
        {
            [self.labelFpsGif setStringValue:@"0.0"];
        }
        [self hideFpsFromFile:NO];
        
        // disable time interval slider in case an file is selected
        [self enableSliderChangeInterval:NO];
    }
    
    
    // set the visible value in dialog to the last saved value
    [self.textFieldFileUrl setStringValue:gifFileName];
    [self.sliderFpsManual setDoubleValue:frameRate];
    [self.checkButtonSetFpsManual setState:frameRateManual];
    [self.checkButtonLoadIntoMem setState:loadAniToMem];
    [self.popupButtonViewOptions selectItemWithTag:viewOpt];
    [self.sliderChangeInterval setIntegerValue:changeInter];
    [self.labelChangeInterval setStringValue:[self.sliderChangeInterval stringValue]];
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
    float frameRate = [self.sliderFpsManual floatValue];
    NSString *gifFileName = [self.textFieldFileUrl stringValue];
    BOOL frameRateManual = self.checkButtonSetFpsManual.state;
    BOOL loadAniToMem = self.checkButtonLoadIntoMem.state;
    NSInteger viewOpt = self.popupButtonViewOptions.selectedTag;
    NSColor *colorPicked = self.colorWellBackgrColor.color;
    NSInteger changeInt = [self.sliderChangeInterval integerValue];
    
    // write values back to screensaver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults setObject:gifFileName forKey:@"GifFileName"];
    [defaults setFloat:frameRate forKey:@"GifFrameRate"];
    [defaults setBool:frameRateManual forKey:@"GifFrameRateManual"];
    [defaults setBool:loadAniToMem forKey:@"LoadAniToMem"];
    [defaults setInteger:viewOpt forKey:@"ViewOpt"];
    [defaults setFloat:colorPicked.redComponent forKey:@"BackgrRed"];
    [defaults setFloat:colorPicked.greenComponent forKey:@"BackgrGreen"];
    [defaults setFloat:colorPicked.blueComponent forKey:@"BackgrBlue"];
    [defaults setInteger:changeInt forKey:@"ChangeInterval"];
    [defaults synchronize];
    
    // set new values to object attributes
    viewOption = viewOpt;
    backgrRed = colorPicked.redComponent;
    backgrGreen = colorPicked.greenComponent;
    backgrBlue = colorPicked.blueComponent;
    
    // close color dialog and options dialog
    [[NSColorPanel sharedColorPanel] close];
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
}

- (IBAction)closeConfigCancel:(id)sender
{
    // close color dialog and options dialog
    [[NSColorPanel sharedColorPanel] close];
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
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
    [self.labelChangeInterval setStringValue:[self.sliderChangeInterval stringValue]];
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
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    
    // Enable the selection of directories in the dialog.
    [openDlg setCanChooseDirectories:YES];
    
    // Disable the selection of more than one file
    [openDlg setAllowsMultipleSelection:NO];

    // set dialog to one levele obove of last selected file/directory
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
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [openDlg URLs];
        
        NSURL *newSelectedFileOrDir = [files objectAtIndex:0];
        
        // set GUI element with selected URL
        [self.textFieldFileUrl setStringValue:newSelectedFileOrDir.absoluteString];
        
        
        if ([self isDir:newSelectedFileOrDir.absoluteString])
        {
            // if we have an directory an fps value for a file makes not much sense
            // we could calculate it for an randomly selected file but this would make thinks to complex
            [self.labelFpsGif setStringValue:@"(dir)"];
            [self hideFpsFromFile:YES];
            
            // enable time interval slider only in case that an directory is selected
            [self enableSliderChangeInterval:YES];
        }
        else
        {
            // update file fps in GUI
            CGImageSourceRef source = CGImageSourceCreateWithURL ( (__bridge CFURLRef) [NSURL URLWithString:newSelectedFileOrDir.absoluteString], NULL);
            if (source)
            {
                CFDictionaryRef cfdProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
                NSDictionary *properties = CFBridgingRelease(cfdProperties);
                float duration = [[[properties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                                   objectForKey:(__bridge NSString *) kCGImagePropertyGIFUnclampedDelayTime] doubleValue];
                CFRelease(source);
                float fps = 1/duration;
                
                [self.labelFpsGif setStringValue:[NSString stringWithFormat:@"%2.1f", fps]];
            }
            else
            {
                [self.labelFpsGif setStringValue:@"0.0"];
            }
            [self hideFpsFromFile:NO];
            
            // disable time interval slider only in case that an file is selected
            [self enableSliderChangeInterval:NO];
        }
        
    }
    
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
    
    
    // set values here...
    NSDictionary *cfg  = @{@"Label":@"com.waitsnake.animatedgif", @"ProgramArguments":@[@"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine",@"-background"], @"KeepAlive":@{@"OtherJobEnabled":@{@"com.apple.SystemUIServer.agent":@YES,@"com.apple.Finder":@YES,@"com.apple.Dock.agent":@YES}}, @"ThrottleInterval":@0};
    [plist addEntriesFromDictionary:cfg];
    
    // saves the agent plist file
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.waitsnake.animatedgif.plist"];
    [plist writeToFile:userLaunchAgentsPath atomically:YES];
    [plist removeAllObjects];
    
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
            // directory includes one or more GIF files
                
            // how many GIF files we have found
            NSInteger numberOfFiles = [filesFilter count];
                
            // generate an random number with upper boundary of the number of found GIF files
            NSInteger randFile = (NSInteger)arc4random_uniform((u_int32_t)numberOfFiles);
                
            // return a NSString of with an URL of the randomly selected GIF in the list
            return [[filesFilter objectAtIndex:randFile] absoluteString];
        }
        else
        {
            // directory includes not a single GIF
                
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

@end
