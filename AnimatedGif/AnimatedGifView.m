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
    currFrameCount = -1;
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1/15.0];
    }
    
    // initalize screensaver defaults with an default value
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                 @"file:///Users/koehmarc/Pictures/animation.gif", @"GifFileName", @"15.0", @"GifFrameRate", @"NO", @"GifFrameRateManual", @"YES", @"StretchGif", nil]];
    
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
        [[NSColor colorWithDeviceRed: 0.0 green: 0.0
                                blue: 0.0 alpha: 1.0] set];
        [NSBezierPath fillRect: screenRect];
    }
    else
    {
        // first clear screen with black
        [[NSColor colorWithDeviceRed: 0.0 green: 0.0
                                blue: 0.0 alpha: 1.0] set];
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
    
    // set the visable value in dialog to the last saved value
    [self.textField1 setStringValue:gifFileName];
    [self.slider1 setDoubleValue:frameRate];
    [self.checkButton1 setState:frameRateManual];
    [self.checkButton2 setState:stretchImage];
    
    return self.optionsPanel;
}

- (IBAction)closeConfigPos:(id)sender {
    // read values from GUI elements
    float frameRate = [self.slider1 floatValue];
    NSString *gifFileName = [self.textField1 stringValue];
    BOOL frameRateManual = self.checkButton1.state;
    BOOL stretchImage = self.checkButton2.state;
    shouldStretchImg = self.checkButton2.state;
    
    // write values back to screensver defaults
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName:[[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults setObject:gifFileName forKey:@"GifFileName"];
    [defaults setFloat:frameRate forKey:@"GifFrameRate"];
    [defaults setBool:frameRateManual forKey:@"GifFrameRateManual"];
    [defaults setBool:stretchImage forKey:@"StretchGif"];
    [defaults synchronize];
    
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
}

- (IBAction)closeConfigNeg:(id)sender {
    [[NSApplication sharedApplication] endSheet:self.optionsPanel];
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
    
    // try to 'focus' only on GIF files (Yes, I know all image types are working with NSImage and if some edit the file URL directly it will open that file too)
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
