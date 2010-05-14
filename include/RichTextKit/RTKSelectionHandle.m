//
//  EditorSelectionHandle.m
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


#import "RTKSelectionHandle.h"

@implementation RTKSelectionHandle


- (id)initWithFrame:(CGRect)frame position:(RTKSelectionHandlePostition)position {
    if ((self = [super initWithFrame:frame])) {
		// Initialization code
		[self setBackgroundColor:[UIColor blueColor]];

		_position = position;
		_bull = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"RTKSelectionHandle.png"]] retain];
		
		[self addSubview:_bull];
		
    }
    return self;
}

- (void)dealloc {
	[_bull release];
	[super dealloc];
}

-(void)setCaretRect:(CGRect)rect;
{
	[self setFrame:rect];

	CGPoint myCenter = CGPointZero;
	
	myCenter.x = self.bounds.size.width / 2;
	if (_position == RTKSelectionHandlePostitionStart) {
		myCenter.y = -6;
	} else {
		myCenter.y = self.bounds.size.height + 6;
	}
	[_bull setCenter:myCenter];
	[_bull setNeedsDisplay];
}


@end
