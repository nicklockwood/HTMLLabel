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


UIKIT_EXTERN NSString *const HTMLBold; //bold
UIKIT_EXTERN NSString *const HTMLItalic; //italic
UIKIT_EXTERN NSString *const HTMLUnderline; // underline
UIKIT_EXTERN NSString *const HTMLFont; // font
UIKIT_EXTERN NSString *const HTMLTextSize; // textSize
UIKIT_EXTERN NSString *const HTMLTextColor; // textColor
UIKIT_EXTERN NSString *const HTMLTextAlignment; // textAlignment


@interface UIFont (Variants)

- (UIFont *)boldFontOfSize:(CGFloat)size;
- (UIFont *)italicFontOfSize:(CGFloat)size;
- (UIFont *)boldItalicFontOfSize:(CGFloat)size;

@end


@interface NSString (HTMLRendering)

- (CGSize)sizeForWidth:(CGFloat)width withHTMLStyles:(NSDictionary *)stylesheet;
- (void)drawInRect:(CGRect)rect withHTMLStyles:(NSDictionary *)stylesheet;

@end


@class HTMLLabel;


@protocol HTMLLabelDelegate <NSObject>
@optional

- (void)HTMLLabel:(HTMLLabel *)label tappedLinkWithURL:(NSURL *)URL bounds:(CGRect)bounds;
- (BOOL)HTMLLabel:(HTMLLabel *)label shouldOpenURL:(NSURL *)URL;

@end


@interface HTMLLabel : UILabel

@property (nonatomic, weak_delegate) IBOutlet id<HTMLLabelDelegate> delegate;
@property (nonatomic, copy) NSDictionary *stylesheet;

@end
