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
    if (self) {
        [self setAnimationTimeInterval:1/15.0];
    }
    
    // initalize screensaver defaults with an default value
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                 @"file:///Users/koehmarc/Pictures/animation.gif", @"GifFileName", @"15.0", @"GifFrameRate", @"NO", @"GifFrameRateManual", @"YES", @"StretchGif", @"0.0", @"BackgrRed", @"0.0", @"BackgrGreen", @"0.0", @"BackgrBlue",nil]];
    
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
    
    // get filename from screensaver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    NSString *gifFileName = [defaults objectForKey:@"GifFileName"];
    float frameRate = [defaults floatForKey:@"GifFrameRate"];
    BOOL frameRateManual = [defaults boolForKey:@"GifFrameRateManual"];
    shouldStretchImg = [defaults boolForKey:@"StretchGif"];
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
        
    }
    else
    {
        currFrameCount = -1;
    }
}

- (void)stopAnimation
{
    [super stopAnimation];
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
    
    if (shouldStretchImg==NO)
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
    

    if (currFrameCount == -1)
    {
        // first clear screen with black
        [[NSColor colorWithDeviceRed: backgrRed green: backgrGreen
                                blue: backgrBlue alpha: 1.0] set];
        [NSBezierPath fillRect: screenRect];
    }
    else
    {
        // first clear screen with black
        [[NSColor colorWithDeviceRed: backgrRed green: backgrGreen
                                blue: backgrBlue alpha: 1.0] set];
        [NSBezierPath fillRect: screenRect];

        //select current frame from GIF (Hint: gifRep is a sub-object from img)
        [gifRep setProperty:NSImageCurrentFrame withValue:@(currFrameCount)];
            
        // draw the selected frame
        if ([self isPreview] == TRUE)
        {
            // In Prefiew Mode Core Image is not working (?) so we make a classical image draw
            [img drawInRect:target];
        }
        else
        {
            // if we have no Preview Mode we use Core Image to draw
            CIImage * ciImage = [[CIImage alloc] initWithBitmapImageRep:gifRep];
            [ciImage drawInRect:target fromRect:NSMakeRect(0,0,img.size.width,img.size.height) operation:NSCompositeCopy fraction:1.0];
            
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
    BOOL stretchImage = [defaults boolForKey:@"StretchGif"];
    float bgrRed = [defaults floatForKey:@"BackgrRed"];
    float bgrGreen = [defaults floatForKey:@"BackgrGreen"];
    float bgrBlue = [defaults floatForKey:@"BackgrBlue"];
    
    // set the visable value in dialog to the last saved value
    [self.textField1 setStringValue:gifFileName];
    [self.slider1 setDoubleValue:frameRate];
    [self.checkButton1 setState:frameRateManual];
    [self.checkButton2 setState:stretchImage];
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
    BOOL stretchImage = self.checkButton2.state;
    NSColor *colorPicked = self.colorWell1.color;
    
    // write values back to screensver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults setObject:gifFileName forKey:@"GifFileName"];
    [defaults setFloat:frameRate forKey:@"GifFrameRate"];
    [defaults setBool:frameRateManual forKey:@"GifFrameRateManual"];
    [defaults setBool:stretchImage forKey:@"StretchGif"];
    [defaults setFloat:colorPicked.redComponent forKey:@"BackgrRed"];
    [defaults setFloat:colorPicked.greenComponent forKey:@"BackgrGreen"];
    [defaults setFloat:colorPicked.blueComponent forKey:@"BackgrBlue"];
    [defaults synchronize];
    
    // set new values to object attributes
    shouldStretchImg = stretchImage;
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
