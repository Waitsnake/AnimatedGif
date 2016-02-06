//
//  AnimatedGifView.m
//  AnimatedGif
//
//  Created by Marco Köhler on 09.11.15.
//  Copyright (c) 2015 Marco Köhler. All rights reserved.
//

#import "AnimatedGifView.h"

#define LOAD_BTN    0
#define UNLOAD_BTN  1

@implementation AnimatedGifView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    currFrameCount = -1;
    self = [super initWithFrame:frame isPreview:isPreview];
    
    // initalize screensaver defaults with an default value
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                 @"file:///please/select/an/gif/animation.gif", @"GifFileName", @"15.0", @"GifFrameRate", @"NO", @"GifFrameRateManual", @"0", @"ViewOpt", @"0.0", @"BackgrRed", @"0.0", @"BackgrGreen", @"0.0", @"BackgrBlue", @"NO", @"LoadAniToMem",nil]];
    
    if (self) {
        self.glView = [self createGLView];
        [self setAnimationTimeInterval:1/15.0];
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
    
    GLint swapInterval = 1; // request synchronization
    //GLint swapInterval = 0; // disable synchronization
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


- (void)startAnimation
{
    [super startAnimation];
    
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

    
    // load GIF image
    img = [[NSImage alloc] initWithContentsOfURL:[NSURL URLWithString:gifFileName]];
    if (img)
    {
        gifRep = [[img representations] objectAtIndex:0];
        [gifRep setProperty:NSImageLoopCount withValue:@(0)]; //infinite loop
        maxFrameCount = [[gifRep valueForProperty: NSImageFrameCount] integerValue];
        currFrameCount = 0;
        
        if(frameRateManual)
        {
            // set frame rate manual
            [self setAnimationTimeInterval:1/frameRate];
        }
        else
        {
            // set frame duration from data from gif file
            float currFrameDuration = [[gifRep valueForProperty: NSImageCurrentFrameDuration] floatValue];
            [self setAnimationTimeInterval:currFrameDuration];
        }
        
        // add glview to screensaver view in case of not in preview mode
        if ([self isPreview] == FALSE)
        {
            [self addSubview:self.glView];
        }
        
        // in case of no review mode and active config option create an array in memory with all frames of bitmap in bitmap format (can be used directly as opengl texture)
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
                // copy the bitmap data into an NSData object, that can be save transfered to animateOneFrame
                NSData *imgData = [[NSData alloc] initWithBytes:data length:size];
                [animationImages addObject:imgData];
                
            }
        }
        
    }
    else
    {
        currFrameCount = -1;
    }
    
}

- (void)stopAnimation
{
    [super stopAnimation];
    if ([self isPreview] == FALSE)
    {
        // remove glview from screensaver view
        [self removeFromSuperview];
    }
    if ([self isPreview] == FALSE)
    {
        /*clean all precalulated bitmap images*/
        [animationImages removeAllObjects];
    }
    currFrameCount = -1;
}

- (BOOL)isOpaque {
    // this keeps Cocoa from unneccessarily redrawing our superview
    return YES;
}

- (void)animateOneFrame
{
    // set some values screensaver and GIF image size
    NSRect screenRect = [self bounds];
    NSRect target = screenRect;
    float screenRatio = [self pictureRatioFromWidth:screenRect.size.width andHeight:screenRect.size.height];
    float imgRatio = [self pictureRatioFromWidth:img.size.width andHeight:img.size.height];
    
    if (viewOption==0)
    {
        // try to fit image optimal to screen
        if (imgRatio >= screenRatio)
        {
            target.size.height = [self calcHeightFromRatio:imgRatio andWidth:screenRect.size.width];
            target.origin.y = (screenRect.size.height - target.size.height)/2;
        }
        else
        {
            target.size.width = [self calcWidthFromRatio:imgRatio andHeight:screenRect.size.height];
            target.origin.x = (screenRect.size.width - target.size.width)/2;
        }
    }
    else if (viewOption==1)
    {
        target = screenRect;
    }
    else if (viewOption==2)
    {
        target.size.height = img.size.height;
        target.size.width = img.size.width;
        target.origin.y = (screenRect.size.height - img.size.height)/2;
        target.origin.x = (screenRect.size.width - img.size.width)/2;
    }
    else
    {
        // in case option in defaults file was too large we set it to last valid value
        target.size.height = img.size.height;
        target.size.width = img.size.width;
        target.origin.y = (screenRect.size.height - img.size.height)/2;
        target.origin.x = (screenRect.size.width - img.size.width)/2;
    }
    
    if (currFrameCount == -1)
    {
        if ([self isPreview] == TRUE)
        {
            // only clear screen with background color (not OpenGL)
            [[NSColor colorWithDeviceRed: backgrRed green: backgrGreen
                                blue: backgrBlue alpha: 1.0] set];
            [NSBezierPath fillRect: screenRect];
        }
        else
        {
            // only clear screen with background color (OpenGL)
            [self.glView.openGLContext makeCurrentContext];
            glClearColor(backgrRed, backgrGreen, backgrBlue, 1.0f);
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
            
            // In Prefiew Mode OpenGL leads to crashes (?) so we make a classical image draw
            
            //select current frame from GIF (Hint: gifRep is a sub-object from img)
            [gifRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
            
            // than clear screen with background color
            [[NSColor colorWithDeviceRed: backgrRed green: backgrGreen
             blue: backgrBlue alpha: 1.0] set];
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
            glClearColor(backgrRed, backgrGreen, backgrBlue, 1.0f);
            glClear(GL_COLOR_BUFFER_BIT);
            
            // Start phase
            glPushMatrix();
            
            // defines the pixel resolution of the screen (can be smaler than real screen, but than you will see pixels)
            glOrtho(0,screenRect.size.width,screenRect.size.height,0,-1,1);
            
            glEnable(GL_TEXTURE_2D);
            
            // load current bitmap as texture into the GPU
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
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
            
            // define the target position of texture (related to screen defined by glOrtho) witch makes the texture visable
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
            
            glDisable(GL_TEXTURE_2D);
            
            //End phase
            glPopMatrix();
            
            glFlush();
            [self.glView.openGLContext flushBuffer];
            
            [self setNeedsDisplay:YES];
            
            // we change the window level only, if not in preview mode and if the level is allready set by the ScreenSaverEngine to desktop level or lower. This allows the screensaver to be used in normal mode, when a screensaver is on the highest window level and not in background
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
            currFrameCount = 0;
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
    if (viewOpt > 2)
    {
        viewOpt = 0;
    }
    
    
    // set the visable value in dialog to the last saved value
    [self.textField1 setStringValue:gifFileName];
    [self.slider1 setDoubleValue:frameRate];
    [self.checkButton1 setState:frameRateManual];
    [self.checkButton2 setState:loadAniToMem];
    [self.popupButton1 selectItemWithTag:viewOpt];
    [self.slider1 setEnabled:frameRateManual];
    [self.label1 setStringValue:[self.slider1 stringValue]];
    [self.colorWell1 setColor:[NSColor colorWithRed:bgrRed green:bgrGreen blue:bgrBlue alpha:1.0]];
    
    // set sement button depending if the launchagent is active or not
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.stino.animatedgif.plist"];
    BOOL launchAgentFileExists = [[NSFileManager defaultManager] fileExistsAtPath:userLaunchAgentsPath];
    if (launchAgentFileExists == YES)
    {
        self.segmentButton1.selectedSegment = LOAD_BTN;
    }
    else
    {
        self.segmentButton1.selectedSegment = UNLOAD_BTN;
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


- (IBAction)closeConfigPos:(id)sender {
    // read values from GUI elements
    float frameRate = [self.slider1 floatValue];
    NSString *gifFileName = [self.textField1 stringValue];
    BOOL frameRateManual = self.checkButton1.state;
    BOOL loadAniToMem = self.checkButton2.state;
    NSInteger viewOpt = self.popupButton1.selectedTag;
    NSColor *colorPicked = self.colorWell1.color;
    
    // write values back to screensver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults setObject:gifFileName forKey:@"GifFileName"];
    [defaults setFloat:frameRate forKey:@"GifFrameRate"];
    [defaults setBool:frameRateManual forKey:@"GifFrameRateManual"];
    [defaults setBool:loadAniToMem forKey:@"LoadAniToMem"];
    [defaults setInteger:viewOpt forKey:@"ViewOpt"];
    [defaults setFloat:colorPicked.redComponent forKey:@"BackgrRed"];
    [defaults setFloat:colorPicked.greenComponent forKey:@"BackgrGreen"];
    [defaults setFloat:colorPicked.blueComponent forKey:@"BackgrBlue"];
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

- (IBAction)closeConfigNeg:(id)sender {
    // close color dialog and options dialog
    [[NSColorPanel sharedColorPanel] close];
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
}

- (IBAction)pressCheckbox1:(id)sender {
    // enable or disable slider depending on checkbox
    BOOL frameRateManual = self.checkButton1.state;
    if (frameRateManual)
    {
        [self.slider1 setEnabled:YES];
    }
    else
    {
        [self.slider1 setEnabled:NO];
    }
}

- (IBAction)selectSlider1:(id)sender {
    // update label with actual selected value of slider
    [self.label1 setStringValue:[self.slider1 stringValue]];
}

- (IBAction)sendFileButtonAction:(id)sender{
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    
    // Disable the selection of directories in the dialog.
    [openDlg setCanChooseDirectories:NO];
    
    // Disable the selection of more than one file
    [openDlg setAllowsMultipleSelection:NO];

    // set dialog to last selected file
    [openDlg setDirectoryURL:[NSURL URLWithString:[self.textField1 stringValue]]];
    
    // try to 'focus' only on GIF files (Yes, I know all image types are working with NSImage)
    [openDlg setAllowedFileTypes:[[NSArray alloc] initWithObjects:@"gif", @"GIF", nil]];
    
    // Display the dialog.  If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* files = [openDlg URLs];
        
        // set GUI element with selected URL
        [self.textField1 setStringValue:[files objectAtIndex:0]];
        
    }
    
}

- (void)loadAgent {
    // create the plist agent file
    NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
    
    // set values here...
    NSDictionary *cfg  = @{@"Label":@"com.stino.animatedgif", @"ProgramArguments":@[@"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine",@"-background"], @"KeepAlive":@{@"OtherJobEnabled":@{@"com.apple.SystemUIServer.agent":@YES,@"com.apple.Finder":@YES,@"com.apple.Dock.agent":@YES}}, @"ThrottleInterval":@0};
    [plist addEntriesFromDictionary:cfg];
    
    // saves the agent plist file
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.stino.animatedgif.plist"];
    [plist writeToFile:userLaunchAgentsPath atomically:YES];
    
    // start the launch agent
    NSString *cmdstr = [[NSString alloc] initWithFormat:@"launchctl load %@ &", userLaunchAgentsPath];
    system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)unloadAgent {
    // stop the launch agent
    NSString *userLaunchAgentsPath = [[NSString alloc] initWithFormat:@"%@%@%@", @"/Users/", NSUserName(), @"/Library/LaunchAgents/com.stino.animatedgif.plist"];
    NSString *cmdstr = [[NSString alloc] initWithFormat:@"%@%@", @"launchctl unload ", userLaunchAgentsPath];
    system([cmdstr cStringUsingEncoding:NSUTF8StringEncoding]);
    
    // remove the plist agent file
    [[NSFileManager defaultManager] removeItemAtPath:userLaunchAgentsPath error:nil];
}

- (float)pictureRatioFromWidth:(float)iWidth andHeight:(float)iHeight {
    return iWidth/iHeight;
}

- (float)calcWidthFromRatio:(float)iRatio andHeight:(float)iHeight {
    return iRatio*iHeight;
}

- (float)calcHeightFromRatio:(float)iRatio andWidth:(float)iWidth {
    return iWidth/iRatio;
}

@end
