//
//  EditorLoopView.m
//  CoreTextEditor
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


#import "RTKLoupeView.h"
#import <QuartzCore/QuartzCore.h>

@implementation RTKLoupeView

@synthesize magnifyView;
@synthesize touchPoint;

- (id)init {
	
	_animated = NO;
	
	if (self = [self initWithFrame:CGRectZero]) {
	}

	
	return self;
}

- (void)setTouchPoint:(CGPoint)point {
	touchPoint = point;
	if (!_animated) {
		_animated = YES;

		CGRect f = self.frame;
		CGPoint c = self.center;
		
		CGRect half = self.frame;
		half.size.width = 0;
		half.size.height = 0;
		[self setFrame:half];

		CGPoint halfC = self.center;
		halfC.x += f.size.width / 2;
		halfC.y += f.size.height;
		[self setCenter:halfC];
		
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.15];
		[UIView setAnimationDelegate:self];
		[self setFrame:f];
		[self setCenter:c];
		[UIView commitAnimations];
		
	}
}


- (void)dealloc {
	[_cache release];
	[_mask release];
	[_loop release];
	[magnifyView release];
	[super dealloc];
}


- (void)drawRect:(CGRect)rect {
	
	/*
	 if(_cache == nil){
	 UIGraphicsBeginImageContext(self.bounds.size);
	 [self.magnifyView.layer renderInContext:UIGraphicsGetCurrentContext()];
	 _cache = [UIGraphicsGetImageFromCurrentImageContext() retain];
	 UIGraphicsEndImageContext();
	 }
	 */
	
	UIGraphicsBeginImageContext(self.magnifyView.bounds.size);
	[self.magnifyView.layer renderInContext:UIGraphicsGetCurrentContext()];
	_cache = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	CGImageRef imageRef = [_cache CGImage];
	CGImageRef maskRef = [_mask CGImage];
	CGImageRef overlay = [_loop CGImage];
	CGImageRef mask = CGImageMaskCreate(
										CGImageGetWidth(maskRef), 
										CGImageGetHeight(maskRef),
										CGImageGetBitsPerComponent(maskRef), 
										CGImageGetBitsPerPixel(maskRef),
										CGImageGetBytesPerRow(maskRef), 
										CGImageGetDataProvider(maskRef), 
										NULL, 
										true);
	// Copy a portion of the image around the touch point.
	float scale = 2.0f;
	CGRect box = CGRectMake(
							touchPoint.x - ( ( _mask.size.width / scale ) / 2 ), 
							touchPoint.y - ( ( _mask.size.height / scale ) / 2 ), 
							( _mask.size.width / scale),
							( _mask.size.height / scale )
							);
	
	CGImageRef subImage = CGImageCreateWithImageInRect(imageRef, box);
	
	// Create Mask.
	CGImageRef xMaskedImage = CGImageCreateWithMask(subImage, mask);
	
	// Draw the image
	// Retrieve the graphics context
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGAffineTransform xform = CGAffineTransformMake(
													1.0,  0.0,
													0.0, -1.0,
													0.0,  0.0);
	CGContextConcatCTM(context, xform);
	
	CGRect area = CGRectMake(0, 0, _mask.size.width, -_mask.size.height);
	
	CGContextDrawImage(context, area, xMaskedImage);
	CGContextDrawImage(context, area, overlay);
	
}

@end
