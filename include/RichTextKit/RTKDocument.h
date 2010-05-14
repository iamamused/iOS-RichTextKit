//
//  CoreTextView.h
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


#import <UIKit/UIKit.h>
#import "RTKCaret.h"
#import "RTKSelectionHandle.h"
#import "RTKCaretLoupeView.h"
#import "RTKSelectionLoupeView.h"
#import "RTKTextRange.h"

@protocol RTKDocumentDelegate;

@interface RTKDocument : UIView <UIKeyInput, UITextInput, UITextInputTokenizer> {
		
	id<RTKDocumentDelegate> _delegate;
	
	UIScrollView *_parentScrollView;
	
	// Strings
	NSMutableAttributedString *textStore;

	// Timers
	
	NSTimer *_loopTimer;
	NSTimer *_menuTimer;
	NSTimer *_doubletapTimer;
	
	// UI Views
	RTKCaret *caret;
	RTKSelectionHandle *selectionHandleEnd;
	RTKSelectionHandle *selectionHandleStart;

	UIView *_selectionFirstLine;
	UIView *_selectionLastLine;
	UIView *_selectionRange;

	RTKCaretLoupeView * _caretLoop;
	RTKSelectionLoupeView * _selectionLoop;
	
	// UITextInput Properties
	UITextRange *selectedTextRange;
//	UITextRange *markedTextRange;
//	NSDictionary *markedTextStyle;
	id <UITextInputDelegate> inputDelegate;
	id <UITextInputTokenizer> tokenizer;
	UIView *textInputView;
	UITextStorageDirection selectionAffinity;
	
	// Flags
	RTKSelectionHandlePostition _dragSelectionActive;
	bool _dragCaratSelectionActive;
	bool _hasMoved;
	bool _scrollEnabled;
	RTKTextRange *_selectedWord;
	
	NSMutableArray *_lineCache;
	RTKTextPosition *_lastPosition;
	
}

@property (nonatomic, retain) UIScrollView *parentScrollView;

@property (nonatomic, retain) NSMutableAttributedString *textStore;

- (id)initWithFrame:(CGRect)frame delegate:(id<RTKDocumentDelegate>)delegate;


#pragma mark -
#pragma mark UITextInput Protocol

@property (readwrite, copy) UITextRange *selectedTextRange;

/* If text can be selected, it can be marked. Marked text represents provisionally
 * inserted text that has yet to be confirmed by the user.  It requires unique visual
 * treatment in its display.  If there is any marked text, the selection, whether a
 * caret or an extended range, always resides witihin.
 *
 * Setting marked text either replaces the existing marked text or, if none is present,
 * inserts it from the current selection. */ 

//@property (nonatomic, readonly) UITextRange *markedTextRange;                       // Nil if no marked text.
//@property (nonatomic, copy) NSDictionary *markedTextStyle;                          // Describes how the marked text should be drawn.

/* The end and beginning of the the text document. */
@property (nonatomic, readonly) UITextPosition *beginningOfDocument;
@property (nonatomic, readonly) UITextPosition *endOfDocument;

/* A system-provied input delegate is assigned when the system is interested in input changes. */
@property (nonatomic, assign) id <UITextInputDelegate> inputDelegate;

/* A tokenizer must be provided to inform the text input system about text units of varying granularity. */
@property (nonatomic, readonly) id <UITextInputTokenizer> tokenizer;

/* An affiliated view that provides a coordinate system for all geometric values in this protocol.
 * If unimplmeented, the first view in the responder chain will be selected. */
@property (nonatomic, readonly) UIView *textInputView;

/* Selection affinity determines whether, for example, the insertion point appears after the last
 * character on a line or before the first character on the following line in cases where text
 * wraps across line boundaries. */
@property (nonatomic) UITextStorageDirection selectionAffinity;


@end


@protocol RTKDocumentDelegate <NSObject>
@required
- (NSMutableAttributedString *)textForEditing;
- (NSDictionary *)defaultStyle;
@end
