//
//  EditorTextRange.m
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


#import "RTKTextRange.h"
#import "RTKTextPosition.h"

@implementation RTKTextRange
+ (id)rangeWithStart:(RTKTextPosition *)startPosition end:(RTKTextPosition *)endPosition;
{
	RTKTextRange *e = [[RTKTextRange alloc] init];
	[e setStartPostion:startPosition];
	[e setEndPostion:endPosition];
	return [e autorelease];
}

- (BOOL)isEmpty;
{
	return ([(RTKTextPosition *)_end position] - [(RTKTextPosition *)_start position]) == 0;
}

- (int)length;
{
	return [(RTKTextPosition *)_end position] - [(RTKTextPosition *)_start position];
}

- (UITextPosition *)start;
{
	return _start;
}

- (void)setStartPostion:(RTKTextPosition *)position;
{
	_start = [position retain];
}

- (UITextPosition *)end;
{
	return _end;
}

- (void)setEndPostion:(RTKTextPosition *)position;
{
	_end = [position retain];
}

#pragma mark -
#pragma mark NSCopying;

- (id)copyWithZone:(NSZone *)zone
{
	RTKTextRange *copy = [[[self class] allocWithZone: zone] init];

	[copy setEndPostion:(RTKTextPosition *)[self end]];
	[copy setStartPostion:(RTKTextPosition *)[self start]];
	
	return copy;
}


@end
