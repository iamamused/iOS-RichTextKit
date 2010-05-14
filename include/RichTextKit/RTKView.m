//
//  EditorScrollView.m
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


#import "RTKView.h"
#import "RTKDocument.h"

@implementation RTKView

- (id)initWithFrame:(CGRect)frame delegate:(id<RTKDocumentDelegate>)docDel {
	if ((self = [super initWithFrame:frame])) {
		
		self.autoresizesSubviews = NO;
		//self.delegate = self;
		self.userInteractionEnabled = YES;
		self.minimumZoomScale = 1.0f;
		self.maximumZoomScale = 1.0f;
		self.scrollEnabled  = YES;
		self.bounces = YES;
		self.bouncesZoom = NO;
		self.contentSize = CGSizeMake(frame.size.width, frame.size.height ); // will auto rezies baed on content.
		self.scrollsToTop = YES;
		self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		
		// Doc view will self re-adjust height based on text length.
		docView = [[RTKDocument alloc] initWithFrame:CGRectInset(frame, 5.0f, 0.0f) delegate:docDel];
		[docView setParentScrollView:self]; // TODO: move to a delegate.
		[self addSubview:docView];
		
		_dragEditingActive = NO;

	}
	return self;
}

- (void)dealloc {
	[docView release];
	[super dealloc];
}


#pragma mark -
#pragma mark Touch Events



@end
