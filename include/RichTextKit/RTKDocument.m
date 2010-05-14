//
//  CoreTextView.m
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


#import "RTKDocument.h"
#import "RTKTextPosition.h"
#import "RTKTextRange.h"
#import "RTKSelectionHandle.h"

#import <CoreText/CoreText.h>

//#define DEBUG_MODE

#ifdef DEBUG_MODE
#define DebugLog( s, ... ) NSLog( @"<%s : (%d)> log: %@",__FUNCTION__, __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DebugLog( s, ... ) 
#endif

@interface RTKDocument (PrivateMethods)

// Touch Results
- (void)_startSingleTapDelayEditingAction:(NSSet *)touches;
- (void)_startDoubleTapEditingAction:(NSSet *)touches;
- (void)_startDoubleTapDelayEditingAction:(NSSet *)touches;
- (void)_moveEditingAction:(NSSet *)touches;
- (void)_endEditingAction:(NSSet *)touches;

// Handlers
- (void)_showCaretLoop:(NSSet *)touches;
- (void)_moveCaretLoop:(NSSet *)touches;
- (void)_hideCaretLoop:(NSSet *)touches;
- (void)_showSelectionLoop:(NSSet *)touches;
- (void)_moveSelectionLoop:(NSSet *)touches;
- (void)_hideSelectionLoop:(NSSet *)touches;
- (void)_placeSingleTapCaret:(NSSet *)touches;
- (void)_highlightWordAtPosition:(RTKTextPosition *)pos;
- (void)_showSelectMenuForRect:(CGRect)rect;
- (void)_showCCPMenuForRect:(CGRect)rect;

// Menu Actions
- (void)_menuTest;
- (void)_menuSelect;
- (void)_menuSelectAll;
- (void)_menuCut;
- (void)_menuCopy;
- (void)_menuPaste;
- (void)_menuReplace;

@end

@implementation RTKDocument

@synthesize textStore;
@synthesize parentScrollView = _parentScrollView;

@synthesize selectedTextRange;
//@synthesize markedTextRange;
//@synthesize markedTextStyle;
@synthesize inputDelegate;
@synthesize tokenizer;
@synthesize textInputView;
@synthesize selectionAffinity;

#pragma mark -
#pragma mark Initialization

- (id)initWithFrame:(CGRect)frame delegate:(id<RTKDocumentDelegate>)delegate;
{
	if ((self = [super initWithFrame:frame])) {
		
		// Initialization code
		_delegate = [delegate retain];
		
		// Set the background to white.
		self.backgroundColor = [UIColor whiteColor];
		
		_lineCache = [[NSMutableArray array] retain];
		
		// Add a caret Object
		caret = [[[RTKCaret alloc] initWithFrame:CGRectZero] retain];
		
		// Add selection handles
		selectionHandleStart = [[[RTKSelectionHandle alloc] initWithFrame:CGRectZero position:RTKSelectionHandlePostitionStart] retain];
		selectionHandleEnd = [[[RTKSelectionHandle alloc] initWithFrame:CGRectZero position:RTKSelectionHandlePostitionEnd] retain];
		
		_selectionFirstLine = [[[UIView alloc] initWithFrame:CGRectZero] retain];
		_selectionFirstLine.backgroundColor = [UIColor redColor];
		_selectionFirstLine.alpha = 0.15;

		_selectionLastLine = [[[UIView alloc] initWithFrame:CGRectZero] retain];
		_selectionLastLine.backgroundColor = [UIColor yellowColor];
		_selectionLastLine.alpha = 0.15;

		_selectionRange = [[[UIView alloc] initWithFrame:CGRectZero] retain];
		_selectionRange.backgroundColor = [UIColor blueColor];
		_selectionRange.alpha = 0.15;
				
		// Set up the text store
		self.textStore = [_delegate textForEditing];
				
		// Select it to start
		
		UITextRange *range = [RTKTextRange 
							  rangeWithStart:[RTKTextPosition positionWithInteger:10] 
							  end:[RTKTextPosition positionWithInteger:320]];
		[self setSelectedTextRange:range];
		
		
		// loop through the parent view to see if we're in a scroll view.
		// this can only be embedded in ONE scrollview.
		/*
		// needs to run after the view has been added.

		*/
				
	}
	return self;
}


#pragma mark -
#pragma mark Memory Management

- (void)dealloc;
{
	[_lineCache release];
	[selectionHandleStart release];
	[selectionHandleEnd release];
	[caret release];
	[super dealloc];
}


#pragma mark -
#pragma mark Responder

- (BOOL)canBecomeFirstResponder;
{ 
	return YES;
}


#pragma mark -
#pragma mark Touch Events

/*
 Observed touch interactions in iPhone OS 3.2 on text editng fields:
 
 1. Single quick tap without a drag, on release: 
 - Close any menus.
 - Clear any selections.
 - Place caret before or after the word depending on tap proximity. 
 
 2. Single quick tap without a drag repeated in same location after a "long" pause (not a double tap, basically another tap in the same location later): 
 - If the calculated caret placement is the same open the menu.
 
 3. Long single tap: 
 - Disable scrolling.
 - Close any menus.
 - Clear any selections.
 - Show the caret placement loop.
 - Place the caret at the tap location.
 - On end show the menu.
 
 4. Single tap and drag: 
 - Move the scroll view, release does nothing.
 
 5. Double tap: 
 - Highlight the word.
 - Show cut/copy/paste/replace menu.
 
 6. Double tap with hold/drag:
 - Highlight word.
 - Disable scrolling.
 - Show selection loop (square) with short delay that could be cancelled by the end touch.
 - on release select the full word in the direction of ovement if the previous movment was less than x seconds earlier.
 - On release show cut/copy/paste/replace menu
 
 7. Triple (or more) tap
 - Cancel everything and results in #1.
 */

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
	
	if (![self isFirstResponder]) {
		[self becomeFirstResponder];
	}
	
	// Set movement flag.
	_hasMoved = NO;
	
	UITouch *touch = [touches anyObject];
	
	if ([touch tapCount] == 1) {
		
		BOOL startSingleTap = YES;
		if ( ![self.selectedTextRange isEmpty] ) {
			// If the text range isn't empty then
			// we have a selection.
			CGRect touchArea1 = CGRectInset([selectionHandleStart frame], -60, -20);
			CGRect touchArea2 = CGRectInset([selectionHandleEnd frame], -60, -20);
			UITouch *touch = [touches anyObject];
			CGPoint tapLocation = [touch locationInView:self];
			
			//EditorTextPosition *pos = (EditorTextPosition *)[self closestPositionToPoint:tapLocation];
			//EditorTextPosition *start = (EditorTextPosition *)[self.selectedTextRange start];
			//EditorTextPosition *end = (EditorTextPosition *)[self.selectedTextRange end];

			if (CGRectContainsPoint(touchArea1, tapLocation)) {
				DebugLog(@"- Disable Scrolling");
				[[self parentScrollView] setScrollEnabled:NO];
				startSingleTap = NO;
				_dragSelectionActive = RTKSelectionHandlePostitionStart;
				[self performSelector:@selector(_startDoubleTapDelayEditingAction:) withObject:touches afterDelay: 0.15];
			} else if (CGRectContainsPoint(touchArea2, tapLocation)) {
				DebugLog(@"- Disable Scrolling");
				[[self parentScrollView] setScrollEnabled:NO];
				startSingleTap = NO;
				_dragSelectionActive = RTKSelectionHandlePostitionEnd;
				[self performSelector:@selector(_startDoubleTapDelayEditingAction:) withObject:touches afterDelay: 0.15];
			} 
		}
		
		// Show the loop in 0.45 sec.
		if (startSingleTap) {
			[self performSelector:@selector(_startSingleTapDelayEditingAction:) withObject:touches afterDelay: 0.45];
		}
	} else if([touch tapCount] == 2) {
		
		// Cancel the delayed action if it hasn't fired.
		[RTKDocument cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startSingleTapDelayEditingAction:) object:touches];
		
		// Double Tapping immediately cancells scrolling.
		DebugLog(@"- Disable Scrolling");
		[[self parentScrollView] setScrollEnabled:NO];
		
		// Start the action immediately.
		[self _startDoubleTapEditingAction:touches];
	}
	
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
{
	
	// Cancel the delayed action if it hasn't fired.
	[RTKDocument cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startSingleTapDelayEditingAction:) object:touches];
	
	// If editing is active then do the move actions.
	if ( _dragCaratSelectionActive || _dragSelectionActive != RTKSelectionHandlePostitionNone) {
		[self _moveEditingAction:touches];
	} 
	
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
{
	
	// Cancel the delayed action if it hasn't fired.
	[RTKDocument cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startSingleTapDelayEditingAction:) object:touches];

	// Allow the scroll to end.
	[super touchesEnded:touches withEvent:event];

	// If we're in editing mode or we haven't moved
	if (_dragCaratSelectionActive || _dragSelectionActive != RTKSelectionHandlePostitionNone || !_hasMoved) {
		[self _endEditingAction:touches];
	}
	
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
{
	[super touchesCancelled:touches withEvent:event];
}

#pragma mark Touch Results

- (void)_startSingleTapDelayEditingAction:(NSSet *)touches;
{
	DebugLog(@"#3 start");
	DebugLog(@"- Disable Scrolling");
	[[self parentScrollView] setScrollEnabled:NO];
	_dragCaratSelectionActive = YES;
	
	DebugLog(@"- Close any menus");
	UIMenuController *menuCont = [UIMenuController sharedMenuController];
	[menuCont setMenuVisible:NO animated:YES];
	
	DebugLog(@"- Clear selections and place caret");
	[self _placeSingleTapCaret:touches];
	
	DebugLog(@"- Show loop");
	[self _showCaretLoop:touches];

}

- (void)_startDoubleTapEditingAction:(NSSet *)touches;
{
	DebugLog(@"#5 start");
	
	DebugLog(@"- Disable scrolling");
	[[self parentScrollView] setScrollEnabled:NO];
	_dragSelectionActive = RTKSelectionHandlePostitionStart;
	
	DebugLog(@"- Hide menu (possibly from single tap)");
	[[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
	
	DebugLog(@"- Highlight word");
	UITouch *touch = [touches anyObject];
	CGPoint tapLocation = [touch locationInView:self];
	RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
	[self _highlightWordAtPosition:pos];

	DebugLog(@"- Trigger double tap loop delay");
	[self performSelector:@selector(_startDoubleTapDelayEditingAction:) withObject:touches afterDelay: 0.15];
}

- (void)_startDoubleTapDelayEditingAction:(NSSet *)touches;
{
	DebugLog(@"- Show selection loop (square) after a short delay");
	// @TODO this should be the line loop.
	[self _showSelectionLoop:touches];
}

- (void)_moveEditingAction:(NSSet *)touches;
{	
	UITouch *touch = [touches anyObject];
	
	if ([touch tapCount] == 1 && _dragSelectionActive == RTKSelectionHandlePostitionNone) {
		DebugLog(@"#3 move");
		
		DebugLog(@"- Place caret at the drag location");
		CGPoint tapLocation = [touch locationInView:self];
		RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
		[self setSelectedTextRange:[RTKTextRange rangeWithStart:pos end:pos]];
				
		DebugLog(@"- Move caret placement loop");
		[self _moveCaretLoop:touches];
		
	} else if([touch tapCount] == 1 && _dragSelectionActive != RTKSelectionHandlePostitionNone) {
		DebugLog(@"#6 move via single click drag");
		// Single tap selection and drag on a slection handle maintains at least a charatcter as the selection.
		// and doesn't allow drag past the other handle 
		CGPoint tapLocation = [touch locationInView:self];
		RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
		RTKTextPosition *start = (RTKTextPosition *)[self.selectedTextRange start];
		RTKTextPosition *end = (RTKTextPosition *)[self.selectedTextRange end];
		
		switch (_dragSelectionActive) {
			case RTKSelectionHandlePostitionStart:
				if ([self comparePosition:pos toPosition:end] == NSOrderedAscending) {
					// pos < end
					start = pos;
				} else if ([self comparePosition:pos toPosition:end] == NSOrderedDescending) {
					// pos > end so select last character.
					start = [RTKTextPosition positionWithInteger:[end position] - 1];
				}
				[_lastPosition release];
				_lastPosition = [start retain];
				break;
			case RTKSelectionHandlePostitionEnd:
				if ([self comparePosition:pos toPosition:start] == NSOrderedAscending) {
					// pos < start so select first character.
					end = [RTKTextPosition positionWithInteger:[start position] + 1];;
				} else if ([self comparePosition:pos toPosition:start] == NSOrderedDescending) {
					// pos > start
					end = pos;
				}
				[_lastPosition release];
				_lastPosition = [end retain];
				break;
		}
		[self setSelectedTextRange:[RTKTextRange rangeWithStart:start end:end]];
		
		[self _moveSelectionLoop:touches];
		
	} else if([touch tapCount] == 2 && _dragSelectionActive != RTKSelectionHandlePostitionNone) {
		DebugLog(@"#6 move");
		// Double tap selection and drag maintains at least the word as the selection.
		// ANd doesn't care about which handle is dragged.
		CGPoint tapLocation = [touch locationInView:self];
		RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
		RTKTextPosition *start = (RTKTextPosition *)[_selectedWord start];
		RTKTextPosition *end = (RTKTextPosition *)[_selectedWord end];
		if ([self comparePosition:pos toPosition:start] == NSOrderedAscending) {
			// pos < start
			start = pos;
		} else if ([self comparePosition:pos toPosition:end] == NSOrderedDescending) {
			// pos > end
			end = pos;
		}
		[_lastPosition release];
		_lastPosition = [pos retain];
		[self setSelectedTextRange:[RTKTextRange rangeWithStart:start end:end]];

		[self _moveSelectionLoop:touches];

	}		
}

- (void)_endEditingAction:(NSSet *)touches;
{	
		
	if (_dragCaratSelectionActive || _dragSelectionActive != RTKSelectionHandlePostitionNone) {

		[RTKDocument cancelPreviousPerformRequestsWithTarget:self selector:@selector(_startDoubleTapDelayEditingAction:) object:touches];
		DebugLog(@"#3 or #6 end");

		DebugLog(@"- Close loops");
		[self _hideCaretLoop:touches];
		[self _hideSelectionLoop:touches];
		
		DebugLog(@"- Show menu for appropriate selection");
		UITouch *touch = [touches anyObject];
		CGPoint tapLocation = [touch locationInView:self];
		if ([self.selectedTextRange isEmpty]) {
			RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
			[self _showSelectMenuForRect:[self caretRectForPosition:pos]];
		} else {
			RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
			[self _showCCPMenuForRect:[self caretRectForPosition:pos]];
		}
		
	} else {
		DebugLog(@"#1 end");
		DebugLog(@"- Close menus");
		// close any opne menus
		UIMenuController *menuCont = [UIMenuController sharedMenuController];
		[menuCont setMenuVisible:NO animated:YES];
		
		DebugLog(@"- Clear selection & place caret");
		[self _placeSingleTapCaret:touches];		
	}
	
	DebugLog(@"- Re-enable Scrolling");
	[[self parentScrollView] setScrollEnabled:YES];
	_dragCaratSelectionActive = NO;
	_dragSelectionActive = RTKSelectionHandlePostitionNone;
	
}

#pragma mark Handlers

- (void)_showCaretLoop:(NSSet *)touches;
{
	if(_caretLoop == nil){
		
		UIMenuController *menuCont = [UIMenuController sharedMenuController];
		[menuCont setMenuVisible:NO animated:YES];
		
		_caretLoop = [[[RTKCaretLoupeView alloc] init] retain];
		[_caretLoop setMagnifyView:self];
		CGPoint touchPointWin = [[touches anyObject] locationInView:[[UIApplication sharedApplication] keyWindow]];
		[_caretLoop setCenter:CGPointMake(touchPointWin.x, touchPointWin.y - 65)];
		CGPoint touchPoint = [[touches anyObject] locationInView:self];
		[_caretLoop setTouchPoint:touchPoint];
		[_caretLoop setNeedsDisplay];
		
		// Add it to the key window so we don't get a recursive view of the loop.
		[[[UIApplication sharedApplication] keyWindow] addSubview:_caretLoop];
	}	
}

- (void)_moveCaretLoop:(NSSet *)touches;
{
	if(_caretLoop != nil){
		[caret setAnimated:NO];
		CGPoint touchPointWin = [[touches anyObject] locationInView:[[UIApplication sharedApplication] keyWindow]];
		[_caretLoop setCenter:CGPointMake(touchPointWin.x, touchPointWin.y - 65)];
		CGPoint touchPoint = [[touches anyObject] locationInView:self];
		[_caretLoop setTouchPoint:touchPoint];
		[_caretLoop setNeedsDisplay];
	}
}

- (void)_hideCaretLoop:(NSSet *)touches;
{
	if(_caretLoop != nil){
		[caret setAnimated:YES];
		[_caretLoop removeFromSuperview];
		[_caretLoop release];
		_caretLoop = nil;
	}
}

- (void)_showSelectionLoop:(NSSet *)touches;
{
	if(_selectionLoop == nil){
		_selectionLoop = [[[RTKSelectionLoupeView alloc] init] retain];
		[_selectionLoop setMagnifyView:self];
		// TODO Fix it to the handle that is dragged
		CGPoint touchPointWin = [[touches anyObject] locationInView:[[UIApplication sharedApplication] keyWindow]];
		[_selectionLoop setCenter:CGPointMake(touchPointWin.x, touchPointWin.y - 28)];
		CGPoint touchPoint = [[touches anyObject] locationInView:self];
		[_selectionLoop setTouchPoint:touchPoint];
		[_selectionLoop setNeedsDisplay];
		
		// Add it to the key window so we don't get a recursive view of the loop.
		[[[UIApplication sharedApplication] keyWindow] addSubview:_selectionLoop];
	}	
}

- (void)_moveSelectionLoop:(NSSet *)touches;
{
	if(_selectionLoop != nil){
		CGPoint touchPoint = [[touches anyObject] locationInView:self];
		[_selectionLoop setTouchPoint:touchPoint];
		
		CGPoint touchPointWin = [[touches anyObject] locationInView:[[UIApplication sharedApplication] keyWindow]];
		[_selectionLoop setCenter:CGPointMake(touchPointWin.x, touchPointWin.y - 28)];
		
		//CGRect c = [self caretRectForPosition:[self.selectedTextRange start]];
		//[_selectionLoop setCenter:CGPointMake(touchPointWin.x, CGRectGetMaxY(c) - 28)];
		[_selectionLoop setNeedsDisplay];
		
	}
}

- (void)_hideSelectionLoop:(NSSet *)touches;
{
	if(_selectionLoop != nil){
		[_selectionLoop removeFromSuperview];
		[_selectionLoop release];
		_selectionLoop = nil;
	}
}

- (void)_placeSingleTapCaret:(NSSet *)touches;
{
	UITouch *touch = [touches anyObject];
	CGPoint tapLocation = [touch locationInView:self];
	// Find the position at the tap location. 
	RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:tapLocation];
	
	
	//- (UITextRange *)rangeEnclosingPosition:(UITextPosition *)position withGranularity:(UITextGranularity)granularity inDirection:(UITextDirection)direction;   // Returns range of the enclosing text unit of the given granularity, or nil if there is no such enclosing unit.  Whether a boundary position is enclosed depends on the given direction, using the same rule as isPosition:withinTextUnit:inDirection:
	//- (BOOL)isPosition:(UITextPosition *)position atBoundary:(UITextGranularity)granularity inDirection:(UITextDirection)direction;                             // Returns YES only if a position is at a boundary of a text unit of the specified granularity in the particular direction.
	//- (UITextPosition *)positionFromPosition:(UITextPosition *)position toBoundary:(UITextGranularity)granularity inDirection:(UITextDirection)direction;   // Returns the next boundary position of a text unit of the given granularity in the given direction, or nil if there is no such position.
	//- (BOOL)isPosition:(UITextPosition *)position withinTextUnit:(UITextGranularity)granularity inDirection:(UITextDirection)direction;                         // Returns YES if position is within a text unit of the given granularity.  If the position is at a boundary, returns YES only if the boundary is part of the text unit in the given direction.
	
	RTKTextRange *rangeTest;
	RTKTextPosition *caretPos;
	
	if (
		[self.tokenizer isPosition:pos atBoundary:UITextGranularityWord inDirection:UITextStorageDirectionForward]
		|| [self.tokenizer isPosition:pos atBoundary:UITextGranularityWord inDirection:UITextStorageDirectionBackward]
	) {
		// We're on a boundary.
		caretPos = pos;
	} else if ([self.tokenizer isPosition:pos withinTextUnit:UITextGranularityWord inDirection:UITextStorageDirectionForward]) {
		// It's within a word or at the beginning
		rangeTest = (RTKTextRange *)[self.tokenizer 
							rangeEnclosingPosition:pos
							withGranularity:UITextGranularityWord 
							inDirection:UITextStorageDirectionForward];
		NSInteger offset = [self offsetFromPosition:[rangeTest start] toPosition:pos];
		float half = [rangeTest length]/2;
		if (offset < half) {
			caretPos = (RTKTextPosition *)[rangeTest start];
		} else {
			caretPos = (RTKTextPosition *)[rangeTest end];
		}
		
	} else if ([self.tokenizer isPosition:pos withinTextUnit:UITextGranularityWord inDirection:UITextStorageDirectionBackward]) {
		// It's within a word or at the end
		rangeTest = (RTKTextRange *)[self.tokenizer 
							rangeEnclosingPosition:pos
							withGranularity:UITextGranularityWord 
							inDirection:UITextStorageDirectionBackward];
		NSInteger offset = [self offsetFromPosition:[rangeTest start] toPosition:pos];
		float half = [rangeTest length]/2;
		if (offset < half) {
			caretPos = (RTKTextPosition *)[rangeTest start];
		} else {
			caretPos = (RTKTextPosition *)[rangeTest end];
		}
	} else {
		// The position is not within a word. 
		caretPos = (RTKTextPosition *)[self.tokenizer 
						  positionFromPosition:pos 
						  toBoundary:UITextGranularityCharacter
						  inDirection:UITextStorageDirectionForward];
		if (!caretPos) {
			caretPos = (RTKTextPosition *)[self.tokenizer 
											  positionFromPosition:pos 
											  toBoundary:UITextGranularityCharacter
											  inDirection:UITextStorageDirectionBackward];
		}
		
	}
		 
	if (!caretPos) {
		caretPos = pos;
	}
	
	DebugLog(@"Position at point: %d,%d", [pos position], [caretPos position]);

	if (_caretLoop == nil && [self.selectedTextRange isEmpty] && [self comparePosition:caretPos toPosition:[self.selectedTextRange start]] == NSOrderedSame ) {
		// Caret is already in place. Open the menu.
		[self _showSelectMenuForRect:[self caretRectForPosition:pos]];
	} else {
		// Place the caret.
		[self setSelectedTextRange:[RTKTextRange rangeWithStart:caretPos end:caretPos]];
	}
	
}

- (void)_highlightWordAtPosition:(RTKTextPosition *)pos;
{
	RTKTextRange *word = (RTKTextRange *)[self.tokenizer 
												rangeEnclosingPosition:pos
												withGranularity:UITextGranularityWord 
												inDirection:UITextStorageDirectionForward];
	if ( !word || [word isEmpty] ) {
		word = (RTKTextRange *)[self.tokenizer 
								   rangeEnclosingPosition:pos
								   withGranularity:UITextGranularityWord 
								   inDirection:UITextStorageDirectionBackward];
		
	}
	if (word) {
		[self setSelectedTextRange:word];	
		
		[_selectedWord release];
		_selectedWord = nil;
		_selectedWord = [word retain];
	}
}

- (void)_showSelectMenuForRect:(CGRect)rect;
{
	UIMenuItem *select = [[UIMenuItem alloc] initWithTitle:@"Select" action:@selector(_menuSelect)];
	UIMenuItem *selectAll = [[UIMenuItem alloc] initWithTitle:@"Select All" action:@selector(_menuSelectAll)];
	UIMenuItem *paste = [[UIMenuItem alloc] initWithTitle:@"Paste" action:@selector(_menuPaste)];
	
	UIMenuController *menuCont = [UIMenuController sharedMenuController];
	[menuCont setTargetRect:[self caretRectForPosition:[self.selectedTextRange start]] inView:self];
	menuCont.arrowDirection = UIMenuControllerArrowDefault;
	menuCont.menuItems = [NSArray arrayWithObjects:select, selectAll, paste, nil ];
	[menuCont setMenuVisible:YES animated:YES];	
}

- (void)_showCCPMenuForRect:(CGRect)rect;
{
	UIMenuItem *cut = [[UIMenuItem alloc] initWithTitle:@"Cut" action:@selector(_menuCut)];
	UIMenuItem *copy = [[UIMenuItem alloc] initWithTitle:@"Copy" action:@selector(_menuCopy)];
	UIMenuItem *paste = [[UIMenuItem alloc] initWithTitle:@"Paste" action:@selector(_menuPaste)];
	//UIMenuItem *replace = [[UIMenuItem alloc] initWithTitle:@"Replace..." action:@selector(_menuReplace)];
	
	UIMenuController *menuCont = [UIMenuController sharedMenuController];
	[menuCont setTargetRect:[_selectionFirstLine frame] inView:self];
	menuCont.arrowDirection = UIMenuControllerArrowDefault;
	menuCont.menuItems = [NSArray arrayWithObjects:cut, copy, paste, nil];
	[menuCont setMenuVisible:YES animated:YES];
}

#pragma mark Menu Actions
- (void)_menuTest;
{
}

- (void)_menuSelect;
{
	// Select the range for the word under the caret
	RTKTextPosition *pos = (RTKTextPosition *)[self.selectedTextRange start];
	[self _highlightWordAtPosition:pos];
	
}

- (void)_menuSelectAll;
{
	UITextRange *range = [RTKTextRange 
						  rangeWithStart:(RTKTextPosition *)[self beginningOfDocument] 
						  end:(RTKTextPosition *)[self endOfDocument]];
	[self setSelectedTextRange:range];
	[self setNeedsDisplay];
}

- (void)_menuCut;
{
	// Implement the PasteBoard
	UIPasteboard *pb = [UIPasteboard generalPasteboard];
	// Set the PasteBoard's string to our CopyString that we created
	[pb setString:[self textInRange:[self selectedTextRange]]];
	
	[self replaceRange:[self selectedTextRange] withText:@""];
}

- (void)_menuCopy;
{
	// Implement the PasteBoard
	UIPasteboard *pb = [UIPasteboard generalPasteboard];
	// Set the PasteBoard's string to our CopyString that we created
	[pb setString:[self textInRange:[self selectedTextRange]]];
}

- (void)_menuPaste;
{
	// Implement the PasteBoard
	UIPasteboard *pb = [UIPasteboard generalPasteboard];
	// Paste the string that we set in the PasteBoard
	// TODO: style it.
	[self insertText:[pb string]];
}

- (void)_menuReplace;
{
}


#pragma mark -
#pragma mark Drawing

/**
 * Draw the text layou
 */
- (void)drawRect:(CGRect)rect;
{

	// Initialize a graphics context and set the text matrix to a known value.
	CGContextRef context = UIGraphicsGetCurrentContext();
	float viewHeight = self.bounds.size.height;
	CGContextTranslateCTM(context, 0, viewHeight);
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	
	// Initialize a rectangular path.
	CGMutablePathRef path = CGPathCreateMutable();
	CGRect textBounds = CGRectMake(0.0, 0.0, self.bounds.size.width, viewHeight);
	CGPathAddRect(path, NULL, textBounds);
	
	// Get the string we'll be drawing.
	CFMutableAttributedStringRef attrString = (CFMutableAttributedStringRef)self.textStore;
	
	// Create a framesetter for it.
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
	
	// Create the frame and draw it into the graphics context
	CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
	CFRelease(framesetter);
	
	// Draw the selection highlight first (if any)
	/*
	if (![self.selectedTextRange isEmpty]) {
		int start = [(EditorTextPosition *)self.selectedTextRange.start position];
		int end = [(EditorTextPosition *)self.selectedTextRange.end position];
		
		// TODO check if the visible range in window includes the seleciton
		
		// Loop through the lines until we find the ones we want to highlight.
		CFArrayRef lines = CTFrameGetLines(frame);
		CFIndex numLines = CFArrayGetCount(lines);
		CFIndex glyphCount = 0;
		BOOL highlight = NO;
		CGPoint pLineOrigin = CGPointMake(0.0, viewHeight);
		BOOL multiLine = NO;
		for(CFIndex index = 0; index < numLines; index++)
		{
			CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, index);
			
			glyphCount += CTLineGetGlyphCount(line);
			
			// Assume start is at 0 for now.
			CGFloat xStart = 0; 
			
			// Get the line propertines and for now assume that the highlight ends at the end of the line.
			CGFloat ascent, descent, leading;
			CGFloat xEnd = CTLineGetTypographicBounds(line, &ascent,  &descent, &leading);
			
			// Get the y-offest line origin
			CGPoint lineOrigin;
			CTFrameGetLineOrigins(frame, CFRangeMake(index, 1), &lineOrigin);
			
			if (glyphCount >= start && !multiLine) {
				// Start highlighting
				highlight = YES;
				
				// Reset the start x-offest in this line from 0 to the actual inset.
				xStart = CTLineGetOffsetForStringIndex( line, start, NULL);
				
				// make start == end so that this if doesn't fire anymore. Furthere loops will highlight from 0.
				start = end;
			}
			
			if (glyphCount >= end) {
				// This is the last line. The start offest has already been set to 0 or and inset.
				
				// Reset the end x-offest in this line from widht to the actual inset.
				xEnd = CTLineGetOffsetForStringIndex( line, end, NULL);
				
				// highlight the last bit.
				[self _drawHighlightRect:CGRectMake(xStart, lineOrigin.y - descent , xEnd - xStart, pLineOrigin.y - lineOrigin.y ) inContext:context ];				
				
				// Break out of the loop since we finished highlighting.
				break;
			}
			
			if (highlight) {
				multiLine = YES;
				// no end was found so highlight the whole line from 0 to self.bounds.size.width.
				[self _drawHighlightRect:CGRectMake(xStart, lineOrigin.y - descent , self.bounds.size.width, pLineOrigin.y - lineOrigin.y ) inContext:context ];
			}
			
			pLineOrigin = lineOrigin;
		}
		
	}
	
	*/
	
	// Now draw the text
	CTFrameDraw(frame, context);
	
	CFRelease(frame);	
	
	
}

- (void)_drawHighlightRect:(CGRect)rect inContext:(CGContextRef)context;
{
	// Draw the highlight
	CGContextSaveGState(context);
	CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
	CGContextSetAlpha(context, 0.25f);
	CGContextAddRect(context, rect);
	CGContextFillRect(context, rect);
	CGContextRestoreGState(context);	
}

- (CGSize)measureFrame: (CTFrameRef)frame
{
	CGPathRef framePath = CTFrameGetPath(frame);
	CGRect frameRect = CGPathGetBoundingBox(framePath);
	
	CFArrayRef lines = CTFrameGetLines(frame);
	CFIndex numLines = CFArrayGetCount(lines);
	
	CGFloat maxWidth = 0;
	CGFloat textHeight = 0;
	
	// Now run through each line determining the maximum width of all the lines.
	// We special case the last line of text. While we've got it's descent handy,
	// we'll use it to calculate the typographic height of the text as well.
	CFIndex lastLineIndex = numLines - 1;
	for(CFIndex index = 0; index < numLines; index++)
	{
		CGFloat ascent, descent, leading, width;
		CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, index);
		width = CTLineGetTypographicBounds(line, &ascent,  &descent, &leading);
		
		if(width > maxWidth)
		{
			maxWidth = width;
		}
		
		if(index == lastLineIndex)
		{
			// Get the origin of the last line. We add the descent to this
			// (below) to get the bottom edge of the last line of text.
			CGPoint lastLineOrigin;
			CTFrameGetLineOrigins(frame, CFRangeMake(lastLineIndex, 1), &lastLineOrigin);
			
			// The height needed to draw the text is from the bottom of the last line
			// to the top of the frame.
			textHeight =  CGRectGetMaxY(frameRect) - lastLineOrigin.y + descent;
		}
	}
	
	// For some text the exact typographic bounds is a fraction of a point too
	// small to fit the text when it is put into a context. We go ahead and round
	// the returned drawing area up to the nearest point.  This takes care of the
	// discrepencies.
	return CGSizeMake(ceil(maxWidth), ceil(textHeight));
}

#pragma mark -
#pragma mark UITextInputTokenizer Protocol

// Returns range of the enclosing text unit of the given granularity, or nil 
// if there is no such enclosing unit.  Whether a boundary position is enclosed
// depends on the given direction, using the same rule as 
// isPosition:withinTextUnit:inDirection:
- (UITextRange *)rangeEnclosingPosition:(UITextPosition *)position withGranularity:(UITextGranularity)granularity inDirection:(UITextDirection)direction;   
{
	
	switch (granularity) {
		
		case UITextGranularityCharacter: {
			
		} break;
		
		case UITextGranularityWord: {
			
		} break;
		
		case UITextGranularitySentence: {
			
		} break;
		
		case UITextGranularityParagraph: {
			
		} break;
		
		case UITextGranularityLine: {
			
		} break;

		case UITextGranularityDocument: {
			
		} break;
			
	}
	
	
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return nil;
}

// Returns YES only if a position is at a boundary of a text unit of the 
// specified granularity in the particular direction.
- (BOOL)isPosition:(UITextPosition *)position atBoundary:(UITextGranularity)granularity inDirection:(UITextDirection)direction;							
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return NO;
}

// Returns the next boundary position of a text unit of the given granularity
// in the given direction, or nil if there is no such position.
- (UITextPosition *)positionFromPosition:(UITextPosition *)position toBoundary:(UITextGranularity)granularity inDirection:(UITextDirection)direction;  
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return nil;
}

// Returns YES if position is within a text unit of the given granularity.  If 
// the position is at a boundary, returns YES only if the boundary is part of 
// the text unit in the given direction.
- (BOOL)isPosition:(UITextPosition *)position withinTextUnit:(UITextGranularity)granularity inDirection:(UITextDirection)direction;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	/*
	// finds phone number in format nnn-nnn-nnnn
    NSRange r;
    NSString *regEx = @"[0-9]{3}-[0-9]{3}-[0-9]{4}";
    r = [textView.text rangeOfString:regEx options:NSRegularExpressionSearch];
    if (r.location != NSNotFound) {
        DebugLog(@"Phone number is %@", [textView.text substringWithRange:r]);
    } else {
        DebugLog(@"Not found.");
    }
	*/
	return NO;
}


#pragma mark -
#pragma mark UIKeyInput Protocol Methods

- (BOOL)hasText;
{
	if (self.textStore.length > 0) {
		return YES;
	}
	return NO;
}

- (void)insertText:(NSString *)theText;
{
	
	UIMenuController *menuCont = [UIMenuController sharedMenuController];
	[menuCont setMenuVisible:NO animated:YES];

	[self.inputDelegate textWillChange:self];
	
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	NSDictionary *attr = [self textStylingAtPosition:[self.selectedTextRange start] inDirection:UITextStorageDirectionBackward];
	
	if ( self.selectedTextRange == nil) {
		
		// There is no selection so append it to the end.
		NSAttributedString *as = [[NSAttributedString alloc] initWithString:theText attributes:attr];
		[self.textStore appendAttributedString:as];
		[as release];
		
		UITextRange *newRange = [RTKTextRange 
								 rangeWithStart:(RTKTextPosition *)[self endOfDocument] 
								 end:(RTKTextPosition *)[self endOfDocument]];
		[self setSelectedTextRange:newRange];
		
	} else if (![self.selectedTextRange isEmpty]) {
		
		// There is a selection, replace it and maintain the selection.
		[self replaceRange:self.selectedTextRange withText:theText];
		
	} else {
		
		// The selection range is empty so insert at the end of the "range".
		NSAttributedString *as = [[NSAttributedString alloc] initWithString:theText attributes:attr];
		NSUInteger index = [(RTKTextPosition *)self.selectedTextRange.end position];
		[self.textStore insertAttributedString:as atIndex:index];
		[as release];
		
		// Place selection after the new text.
		RTKTextPosition *pos = [RTKTextPosition positionWithInteger: index + [theText length]];
		UITextRange *newRange = [RTKTextRange rangeWithStart:pos end:pos];
		[self setSelectedTextRange:newRange];
		
	}
	
	
	[self.inputDelegate textDidChange:self];
	
	DebugLog([self.textStore description]);
	
	[self setNeedsDisplay];
	
}

- (void)deleteBackward;
{
	
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	NSRange theRange;
	if ( self.selectedTextRange == nil) {
		
		// No selection, delete from end?
		// TODO: should we not delete if no selection.
		theRange = NSMakeRange(self.textStore.length-1, 1);
		
	} else if (![self.selectedTextRange isEmpty]) {
		
		// Delete selection.
		NSUInteger start = [(RTKTextPosition *)self.selectedTextRange.start position];
		NSUInteger length = [(RTKTextPosition *)self.selectedTextRange.end position] - start;
		theRange = NSMakeRange( start, length );
		
	} else {
		
		// Delete from the "end" of the empty range (caret position)
		NSUInteger end = [(RTKTextPosition *)self.selectedTextRange.end position];
		if (end == 0) return;
		theRange = NSMakeRange(end - 1, 1);
		
	}
	
	// Do the deletion
	[self.textStore deleteCharactersInRange:theRange];
	
	// Place the selection at begining of deletion range.
	RTKTextPosition *c = [RTKTextPosition positionWithInteger: theRange.location ];
	UITextRange *newRange = [RTKTextRange rangeWithStart:c end:c];
	[self setSelectedTextRange:newRange];
	
	[self setNeedsDisplay];
	
	
}


#pragma mark -
#pragma mark UITextInput Protocol

#pragma mark Methods for manipulating text

- (NSString *)textInRange:(UITextRange *)range;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	const int length = [(RTKTextPosition *)range.end position] - [(RTKTextPosition *)range.start position];
	unichar chars[length];
	[[self.textStore mutableString] getCharacters:chars range:NSMakeRange([(RTKTextPosition *)range.start position], length)];
	return [NSString stringWithCharacters:chars length:length];
}
- (void)replaceRange:(UITextRange *)range withText:(NSString *)theText;
{
	
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	[self.inputDelegate textWillChange:self];
	
	// Replace the characters in the string
	NSUInteger start = [(RTKTextPosition *)range.start position];
	NSUInteger length = [(RTKTextPosition *)range.end position] - start;
	[self.textStore replaceCharactersInRange:NSMakeRange( start, length ) withString:theText];	
	
	// Place caret at the end of the previously selected text.
	RTKTextPosition *c = [RTKTextPosition positionWithInteger: start + [theText length]];
	UITextRange *newRange = [RTKTextRange rangeWithStart:c  end:c];
	[self setSelectedTextRange:newRange];
	
	[self.inputDelegate textDidChange:self];
	
	[self setNeedsDisplay];
}


/* Text may have a selection, either zero-length (a caret) or ranged.  Editing operations are
 * always performed on the text from this selection.  nil corresponds to no selection. */

- (void)setSelectedTextRange:(UITextRange *)aSelectedTextRange;
{
	
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	[self.inputDelegate selectionWillChange:self];
	
	selectedTextRange = [[aSelectedTextRange copy] retain];
	
	[self.inputDelegate selectionDidChange:self];
	
	RTKTextRange *range = (RTKTextRange *)self.selectedTextRange;

	if ([range isEmpty]) {
		
		// Remove selection handle if they're there.
		[selectionHandleStart removeFromSuperview];
		[selectionHandleEnd removeFromSuperview];
		[_selectionRange removeFromSuperview];
		[_selectionFirstLine removeFromSuperview];
		[_selectionLastLine removeFromSuperview];
		
		// Reposition the caret.
		[caret setFrame:[self caretRectForPosition:(RTKTextPosition *)[range end]]];
		[self addSubview:caret];
		[caret setNeedsDisplay];
		
	} else {

		// Remove caret handle if it's there.
		[caret removeFromSuperview];

		CGRect caratStart = [self caretRectForPosition:(RTKTextPosition *)[range start]];
		CGRect caratEnd = [self caretRectForPosition:(RTKTextPosition *)[range end]];
		
		if (caratStart.origin.y == caratEnd.origin.y ) {
			// The selection is on one line.
			[_selectionFirstLine setFrame:CGRectMake(
												 caratStart.origin.x + caratStart.size.width,
												 caratStart.origin.y,
												 caratEnd.origin.x -caratStart.size.width - caratStart.origin.x,
												 caratStart.size.height
												 )];
			[_selectionFirstLine setNeedsDisplay];
			[_selectionRange removeFromSuperview];
			[_selectionLastLine removeFromSuperview];
			
			[self addSubview:_selectionFirstLine];
		} else {
			// multiline
			[_selectionRange setFrame:CGRectMake(
												 0,
												 caratStart.origin.y + caratStart.size.height,
												 self.bounds.size.width,
												 caratEnd.origin.y - (caratStart.origin.y + caratStart.size.height)
												 )];

			[_selectionFirstLine setFrame:CGRectMake(
												 caratStart.origin.x + caratStart.size.width,
												 caratStart.origin.y,
												 self.bounds.size.width - caratStart.origin.x - caratStart.size.width,
												 caratStart.size.height
												 )];

			[_selectionLastLine setFrame:CGRectMake(
													0,
													caratEnd.origin.y,
													caratEnd.origin.x,
													caratEnd.size.height
													)];
			
			[_selectionRange setNeedsDisplay];
			[_selectionFirstLine setNeedsDisplay];
			[_selectionLastLine setNeedsDisplay];
			
			[self addSubview:_selectionRange];
			[self addSubview:_selectionLastLine];
			[self addSubview:_selectionFirstLine];

			
		}
		
		// Reposition the start handle.
		[selectionHandleStart setCaretRect:caratStart];
		[self addSubview:selectionHandleStart];
		[selectionHandleStart setNeedsDisplay];
		
		// Reposition the end handle.
		[selectionHandleEnd setCaretRect:caratEnd];
		[self addSubview:selectionHandleEnd];
		[selectionHandleEnd setNeedsDisplay];
		
		
		
	}
	
	[self setNeedsDisplay];
	
}
- (UITextRange *)selectedTextRange;
{
	//DebugLog(@"%@",[NSThread callStackSymbols]);	
	DebugLog(@"selectedTextRange");	
	return selectedTextRange;
}


/* If text can be selected, it can be marked. Marked text represents provisionally
 * inserted text that has yet to be confirmed by the user.  It requires unique visual
 * treatment in its display.  If there is any marked text, the selection, whether a
 * caret or an extended range, always resides witihin.
 *
 * Setting marked text either replaces the existing marked text or, if none is present,
 * inserts it from the current selection. */ 

- (void)setMarkedTextRange:(UITextRange *)markedTextRange;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
}
- (UITextRange *)markedTextRange;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return nil; // Nil if no marked text.
}
- (void)setMarkedTextStyle:(NSDictionary *)markedTextStyle;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
}
- (NSDictionary *)markedTextStyle;
{
	// Describes how the marked text should be drawn.
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return nil;
}
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange;  // selectedRange is a range within the markedText
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
}
- (void)unmarkText;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
}


#pragma mark Positions

- (UITextPosition *)beginningOfDocument;
{
	//DebugLog(@"%@",[NSThread callStackSymbols]);
	DebugLog(@"beginningOfDocument");
	return [RTKTextPosition positionWithInteger:0];
}
- (UITextPosition *)endOfDocument;
{
	//DebugLog(@"%@",[NSThread callStackSymbols]);
	DebugLog(@"endOfDocument");
	return [RTKTextPosition positionWithInteger:[self.textStore length] - 1];
}


#pragma mark Methods for creating ranges and positions.

- (UITextRange *)textRangeFromPosition:(UITextPosition *)fromPosition toPosition:(UITextPosition *)toPosition;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return [RTKTextRange rangeWithStart:(RTKTextPosition *)fromPosition end:(RTKTextPosition *)toPosition];
}
- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	RTKTextPosition *p = (RTKTextPosition *)position;
	return [RTKTextPosition positionWithInteger:[p position] + offset];
}
- (UITextPosition *)positionFromPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset;
{
	
	// For arrow keys on a kayboard the start position is the same but indicates and offset for the number of times it was pressed.
	
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	NSUInteger pos = [(RTKTextPosition *)position position];

	DebugLog(@"start position: %d, direction: %d, offset:%d",pos, direction, offset);
	
	switch (direction) {
			
		case UITextLayoutDirectionUp: {
			
			CGRect caretRect = [self caretRectForPosition:position]; // original position, not current.
			CGPoint target = caretRect.origin;
			target.y = target.y - ( caretRect.size.height * (offset - 1) ) - (caretRect.size.height * 0.5f); // half way through "previous" line.
			pos = [(RTKTextPosition *)[self closestPositionToPoint:target] position];
			
		} break;
			
		case UITextLayoutDirectionDown: {
			
			CGRect caretRect = [self caretRectForPosition:position];
			CGPoint target = caretRect.origin;
			target.y = target.y + ( caretRect.size.height * (offset - 1) ) + (caretRect.size.height * 1.5f); // half way through "next" line.
			pos = [(RTKTextPosition *)[self closestPositionToPoint:target] position];
			
		} break;
			
		case UITextLayoutDirectionLeft: {
			
			pos = [(RTKTextPosition *)position position] - offset;
			
		} break;
			
		case UITextLayoutDirectionRight: {
			
			pos = [(RTKTextPosition *)position position] + offset;
			
		} break;
			
		default:
			break;
			
	}
	
	DebugLog( @"new position: %d",pos );

	// This method is called with the arrow key presses. Not sure if this should
	// go here but it works.
	RTKTextPosition *c = [RTKTextPosition positionWithInteger: pos];
	UITextRange *newRange = [RTKTextRange rangeWithStart:c  end:c];
	[self setSelectedTextRange:newRange];
	
	return [RTKTextPosition positionWithInteger:pos];
}

/* Simple evaluation of positions */
- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	/*
	 NSOrderedAscending
	 The left operand is smaller than the right operand.
	 Available in iPhone OS 2.0 and later.
	 Declared in NSObjCRuntime.h.
	 
	 NSOrderedSame
	 The two operands are equal.
	 Available in iPhone OS 2.0 and later.
	 Declared in NSObjCRuntime.h.
	 
	 NSOrderedDescending
	 The left operand is greater than the right operand.
	 Available in iPhone OS 2.0 and later.
	 Declared in NSObjCRuntime.h.
	 */
	
	int a = [(RTKTextPosition *)position position];
	int b = [(RTKTextPosition *)other position];
	
	NSComparisonResult result;
	if ( a < b ) result = NSOrderedAscending;
	else if ( a > b ) result = NSOrderedDescending;
	else result = NSOrderedSame;

	DebugLog(@"a: %d b: %d result: %d",a,b,result);
	
	return result;
}
- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)toPosition;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	int a = [(RTKTextPosition *)from position];
	int b = [(RTKTextPosition *)toPosition position];
	NSInteger result = b - a;
	
	DebugLog(@"from: %d to: %d result: %d",a,b,result);

	return result;
}


/* A system-provied input delegate is assigned when the system is interested in input changes. */
/*
 - (void)setInputDelegate:(id <UITextInputDelegate>)inputDelegate;
 {
 DebugLog(@"%@",[NSThread callStackSymbols]);
 DebugLog(@"%@",inputDelegate);
 }
 - (id <UITextInputDelegate>)inputDelegate;
 {
 DebugLog(@"%@",[NSThread callStackSymbols]);
 return nil;
 }
 */

/* A tokenizer must be provided to inform the text input system about text units of varying granularity. */
 - (id <UITextInputTokenizer>)tokenizer;
 {
	 DebugLog(@"%@",[NSThread callStackSymbols]);
	 if (tokenizer == nil) {
		 tokenizer = [[[UITextInputStringTokenizer alloc] initWithTextInput:self] retain];
	 }
	 return tokenizer;
 }

#pragma mark Layout questions.

- (UITextPosition *)positionWithinRange:(UITextRange *)range farthestInDirection:(UITextLayoutDirection)direction;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return nil;
}
- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)position inDirection:(UITextLayoutDirection)direction;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return nil;
}

#pragma mark Writing direction

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return UITextWritingDirectionLeftToRight;
}
- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange *)range;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
}

#pragma mark Geometry

/* Geometry used to provide, for example, a correction rect. */
- (CGRect)firstRectForRange:(UITextRange *)range;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return CGRectNull;
}
- (CGRect)caretRectForPosition:(UITextPosition *)position;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	// Initialize a graphics context and set the text matrix to a known value.
	float viewHeight = [self textInputView].bounds.size.height;
	float viewWdith = [self textInputView].bounds.size.width;
	CGRect textBounds = CGRectMake(0.0, 0.0, viewWdith, viewHeight);
	
	// Initialize a rectangular path for the text frame
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddRect(path, NULL, textBounds);
	
	// Get the string up to the end of the range
	int caretIndex = [(RTKTextPosition *)position position];
	
	NSAttributedString *subString = [textStore attributedSubstringFromRange:NSMakeRange([(RTKTextPosition *)[self beginningOfDocument] position], caretIndex)];
	CFMutableAttributedStringRef attrString = (CFMutableAttributedStringRef)subString;
	
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
	
	// Create the frame
	CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
	
	// Get the number of lines from the frame.
	CFArrayRef lines = CTFrameGetLines(frame);
	
	// Out text is up to the caret so the last line is the one we want.
	CFIndex count = CFArrayGetCount(lines);
	
	CFIndex lastLineIndex = count -1;
	CGFloat xOffset;
	CGPoint previousLineOrigin = CGPointMake(0.0f, viewHeight);
	CGPoint lastLineOrigin;
	CGFloat ascent, descent, leading, width;
	if (lastLineIndex >= 0) {
		
		// Get the y origin
		if (lastLineIndex > 0) {
			CTFrameGetLineOrigins(frame, CFRangeMake(lastLineIndex - 1, 1), &previousLineOrigin);
		}
		CTFrameGetLineOrigins(frame, CFRangeMake(lastLineIndex, 1), &lastLineOrigin);
		
		CTLineRef lastLine = (CTLineRef)CFArrayGetValueAtIndex(lines, lastLineIndex);
		
		// Get the xoffset
		xOffset = CTLineGetOffsetForStringIndex( lastLine	, caretIndex, NULL);
		
		// Figure out how big to make it
		width = CTLineGetTypographicBounds(lastLine, &ascent,  &descent, &leading);
		
	} else {
		lastLineOrigin = CGPointMake(0.0, 14.0f);
		xOffset = 0;
		width = 0;
		ascent = 14.0;
		descent = 0;
		leading = 0;
	}
	
	// Get the origin of the last line. We add the descent to this
	// (below) to get the bottom edge of the last line of text.
	
	// The height needed to draw the text is from the bottom of the last line
	// to the top of the frame.
	//CGFloat textHeight = CGRectGetMaxY(textBounds) - lastLineOrigin.y + descent;
	
	CFRelease(framesetter);
	CFRelease(frame);
	
	// Core text uses bottom left as the 0,0 point so we need to transpose the coords:
	/*
	 CGContextRef context = UIGraphicsGetCurrentContext();
	 
	 // Save the Context State because we want 
	 // to restore after we are done so we can draw normally again.
	 CGContextSaveGState(context);
	 
	 float viewHeight = self.bounds.size.height;
	 CGContextTranslateCTM(context, 0, viewHeight);
	 CGContextScaleCTM(context, 1.0, -1.0);
	 CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	 
	 
	 // Restore the Context State so drawing returns back to normal
	 CGContextRestoreGState(context);
	 */
	
	float caretWidth = 2.0f;
	float caretHeight = previousLineOrigin.y - lastLineOrigin.y;
	// Transpose to topleft 0,0 with positive descending.
	float yOffset = [self textInputView].bounds.size.height - (lastLineOrigin.y - descent) - caretHeight; 
	
	return CGRectMake(xOffset, yOffset , caretWidth, caretHeight);
}

#pragma mark Hit testing

/* JS - Find the closest position to a given point */
- (UITextPosition *)closestPositionToPoint:(CGPoint)point;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	
	// Initialize a graphics context and set the text matrix to a known value.
	float viewHeight = [self textInputView].bounds.size.height;
	float viewWdith = [self textInputView].bounds.size.width;
	CGRect textBounds = CGRectMake(0.0, 0.0, viewWdith, viewHeight);
	
	// Initialize a rectangular path for the text frame
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathAddRect(path, NULL, textBounds);
	
	CFMutableAttributedStringRef attrString = (CFMutableAttributedStringRef)self.textStore;
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
	CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
	
	// Loop through the lines until we find the ones we want.
	CFArrayRef lines = CTFrameGetLines(frame);
	CFIndex numLines = CFArrayGetCount(lines);
	
	CFIndex position = 0;
	CGPoint lineOrigin = CGPointZero;
	for(CFIndex index = 0; index < numLines; index++)
	{
		CTLineRef line = (CTLineRef) CFArrayGetValueAtIndex(lines, index);
		
		// Get the y-offest line origin
		CTFrameGetLineOrigins(frame, CFRangeMake(index, 1), &lineOrigin);
		
		// Tricky: lines a 0 in bottom left
		if ((viewHeight - lineOrigin.y) >= point.y) {
			// The first line to match will be the one we're looking for.
			position = CTLineGetStringIndexForPosition(line, point);
			
			break;
		}
		
	}
	
	if (position == 0 && !CGPointEqualToPoint(lineOrigin, CGPointZero) ) {
		// Touch was below the last line. 
		return [self endOfDocument]; 
	}
	
	return [RTKTextPosition positionWithInteger:position];
}
- (UITextPosition *)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange *)range;
{
	// @TODO actually modify based on range.
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return range.start;
}
- (UITextRange *)characterRangeAtPoint:(CGPoint)point;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	RTKTextPosition *pos = (RTKTextPosition *)[self closestPositionToPoint:point];
	return [RTKTextRange rangeWithStart:pos end:pos];
}

/* Text styling information can affect, for example, the appearance of a correction rect. */
- (NSDictionary *)textStylingAtPosition:(UITextPosition *)position inDirection:(UITextStorageDirection)direction;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);

	if ([self.textStore length] == 0) {
		return [NSDictionary dictionary];
	}
	
	CFIndex start = [(RTKTextPosition *)position position];
	NSRange effectiveRange;
	if ( direction == UITextStorageDirectionBackward ) {
		effectiveRange = NSMakeRange(start > 0 ? start -1 : 0, 1);
	} else if ( direction == UITextStorageDirectionForward) {
		effectiveRange = NSMakeRange(start, 1);
	}
	return [self.textStore attributesAtIndex:start effectiveRange:&effectiveRange];
}

#pragma mark Not Needed
/* To be implemented if there is not a one-to-one correspondence between text positions within range and character offsets into the associated string. */
/*
 - (UITextPosition *)positionWithinRange:(UITextRange *)range atCharacterOffset:(NSInteger)offset;
 {
 DebugLog(@"%@",[NSThread callStackSymbols]);
 return nil;
 }
 - (NSInteger)characterOffsetOfPosition:(UITextPosition *)position withinRange:(UITextRange *)range;
 {
 DebugLog(@"%@",[NSThread callStackSymbols]);
 return 0;
 }
 */

#pragma Other Getters

/* An affiliated view that provides a coordinate system for all geometric values in this protocol.
 * If unimplmeented, the first view in the responder chain will be selected. */
- (UIView *)textInputView;
{
	//DebugLog(@"%@",[NSThread callStackSymbols]);
	// Use this view for the coordinate system.
	return self;
}

/* Selection affinity determines whether, for example, the insertion point appears after the last
 * character on a line or before the first character on the following line in cases where text
 * wraps across line boundaries. */
/*
 - (void)setSelectionAffinity:(UITextStorageDirection)selectionAffinity;
 {
 DebugLog(@"%@",[NSThread callStackSymbols]);
 }
 */
- (UITextStorageDirection)selectionAffinity;
{
	DebugLog(@"%@",[NSThread callStackSymbols]);
	return UITextStorageDirectionForward;
}

@end
