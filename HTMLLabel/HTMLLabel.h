//
//  HTMLLabel.m
//
//  Version 1.0 beta
//
//  Created by Nick Lockwood on 18/11/2012.
//  Copyright 2012 Charcoal Design
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/HTMLLabel
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <UIKit/UIKit.h>


#import <Availability.h>
#undef weak_delegate
#if __has_feature(objc_arc_weak)
#define weak_delegate weak
#else
#define weak_delegate unsafe_unretained
#endif


static NSString *const HTMLBold = @"bold";
static NSString *const HTMLItalic = @"italic";
static NSString *const HTMLUnderline = @"underline";
static NSString *const HTMLFont = @"font";
static NSString *const HTMLTextSize = @"textSize";
static NSString *const HTMLTextColor = @"textColor";


@interface UIFont (Variants)

- (UIFont *)boldFontOfSize:(CGFloat)size;
- (UIFont *)italicFontOfSize:(CGFloat)size;
- (UIFont *)boldItalicFontOfSize:(CGFloat)size;

@end


@interface HTMLStylesheet : NSObject <NSCopying>

- (id)initWithDictionary:(NSDictionary *)dictionary;
- (HTMLStylesheet *)stylesheetByaddingStyles:(NSDictionary *)styles forSelector:(NSString *)selector;
- (HTMLStylesheet *)stylesheetByaddingStylesFromDictionary:(NSDictionary *)dictionary;

@end


@interface NSString (HTMLRendering)

- (CGSize)sizeWithHtmlStylesheet:(HTMLStylesheet *)stylesheet forWidth:(CGFloat)width;
- (void)drawHtmlInRect:(CGRect)rect withHtmlStylesheet:(HTMLStylesheet *)stylesheet;

@end


@class HTMLLabel;


@protocol HTMLLabelDelegate <NSObject>
@optional

- (void)HTMLLabel:(HTMLLabel *)label tappedLinkWithURL:(NSURL *)URL bounds:(CGRect)bounds;
- (BOOL)HTMLLabel:(HTMLLabel *)label shouldOpenURL:(NSURL *)URL;

@end


@interface HTMLLabel : UILabel

@property (nonatomic, weak_delegate) IBOutlet id<HTMLLabelDelegate> delegate;
@property (nonatomic, copy) HTMLStylesheet *stylesheet;

@end
