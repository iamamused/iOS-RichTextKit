//
//  DemoViewController.m
//  RichTextKit
//
//  The MIT License
//  
//  Copyright (c) 2010 TropicalPixels, Jeffrey Sambells
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "DemoViewController.h"
#import <RichTextKit/RichTextKit.h>
#import <CoreText/CoreText.h>

@implementation DemoViewController

#pragma mark -
#pragma mark RTKDocumentDelegate

- (NSMutableAttributedString *)textForEditing;
{
	// Insert some text to start.
	
	CTFontRef font = CTFontCreateWithName( (CFStringRef)@"Courier", 16, NULL);
	CFStringRef keys[] = { kCTFontAttributeName };
	CFTypeRef values[] = { font };
	CFDictionaryRef attr = CFDictionaryCreate(
											  NULL, 
											  (const void **)&keys, 
											  (const void **)&values,
											  sizeof(keys) / sizeof(keys[0]), 
											  &kCFTypeDictionaryKeyCallBacks, 
											  &kCFTypeDictionaryValueCallBacks
											  );
	
	NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] 
			 initWithString:@"Lorem Ipsum\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Donec vitae turpis urna, aliquam rutrum libero. Quisque justo odio, iaculis non luctus sit amet, bibendum a dolor. Fusce dolor mauris, tempus eget eleifend id, facilisis quis urna. Fusce iaculis congue sem, nec ullamcorper mi rutrum vitae. Proin molestie pellentesque imperdiet. Sed dictum nulla vitae arcu vulputate aliquet. Etiam at rutrum neque. Nam volutpat mollis lacinia. Suspendisse quis tellus massa. Nullam in iaculis metus. Nam dolor turpis, congue luctus fringilla et, congue a urna. Aliquam erat volutpat. Quisque ornare, augue sed mattis vulputate, orci diam varius urna, ut scelerisque lacus urna vitae urna. Cras dictum tempor egestas. Duis eu nibh a diam feugiat dapibus. Sed et libero turpis, in fermentum leo. Etiam vel augue odio, vitae porttitor enim."
			 attributes:(NSDictionary *)attr] autorelease];

	CFRelease(attr);

	
	// Create a color and add it as an attribute to the string.
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	CGFloat components[] = { 0.2, 0.6, 0.2, 1.0 };
	CGColorRef titleColour = CGColorCreate(rgbColorSpace, components);
	CGColorSpaceRelease(rgbColorSpace);
	CFAttributedStringSetAttribute(
		(CFMutableAttributedStringRef)string, 
		CFRangeMake(0, 11), 
		kCTForegroundColorAttributeName,
		titleColour
	);
	
	CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(0, 5), kCTStrokeWidthAttributeName, [NSNumber numberWithFloat:2]);
	CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(0, 5), kCTStrokeColorAttributeName, [UIColor blueColor].CGColor);

	NSLog(@"%@", string);
	return string;
}

- (NSDictionary *)defaultStyle;
{
	return nil;
}

#pragma mark -
#pragma mark View Management

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	UIScreen *screen = [UIScreen mainScreen];
	// Load your primary view here for the demo
	self.view = [[RTKView alloc] initWithFrame:[screen applicationFrame] delegate:self];
}

- (void)dealloc {
    [super dealloc];
}

@end
