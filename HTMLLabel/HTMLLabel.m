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

#import "HTMLLabel.h"


#pragma mark -
#pragma mark Fonts


@implementation UIFont (Variants)

- (UIFont *)fontWithSize:(CGFloat)fontSize traits:(NSArray *)traits
{
    NSMutableArray *blacklist = [@[@"bold", @"oblique", @"light", @"condensed"] mutableCopy];
    for (NSString *trait in traits)
    {
        //is desired trait
        [blacklist removeObject:trait];
    }
    for (NSString *trait in [blacklist reverseObjectEnumerator])
    {
        //is property of base font
        if ([[self.fontName lowercaseString] rangeOfString:trait].location != NSNotFound)
        {
            [blacklist removeObject:trait];
        }
    }
    NSString *familyName = [self familyName];
    
    //special case due to weirdness with iPhone system font
    if ([familyName isEqualToString:@".Helvetica NeueUI"])
    {
        familyName = @"Helvetica Neue";
    }
    
    for (NSString *name in [UIFont fontNamesForFamilyName:familyName])
    {
        BOOL match = YES;
        for (NSString *trait in blacklist)
        {
            if ([[name lowercaseString] rangeOfString:trait].location != NSNotFound)
            {
                match = NO;
                break;
            }
        }
        for (NSString *trait in traits)
        {
            if ([[name lowercaseString] rangeOfString:trait].location == NSNotFound)
            {
                match = NO;
                break;
            }
        }
        if (match)
        {
            return [UIFont fontWithName:name size:fontSize];
        }
    }
    return self;
}

- (UIFont *)boldFontOfSize:(CGFloat)fontSize
{
    return [self fontWithSize:fontSize traits:@[@"bold"]];
}

- (UIFont *)italicFontOfSize:(CGFloat)fontSize
{
    return [self fontWithSize:fontSize traits:@[@"oblique"]];
}

- (UIFont *)boldItalicFontOfSize:(CGFloat)fontSize
{
    return [self fontWithSize:fontSize traits:@[@"bold", @"oblique"]];
}

@end


#pragma mark -
#pragma mark HTML parsing


@interface HTMLTokenAttributes : NSObject <NSMutableCopying>

@property (nonatomic, copy) NSString *href;
@property (nonatomic, assign) BOOL bold;
@property (nonatomic, assign) BOOL italic;
@property (nonatomic, assign) BOOL underlined;
@property (nonatomic, assign) BOOL list;
@property (nonatomic, assign) NSInteger nextListIndex;

@end


@implementation HTMLTokenAttributes

- (id)mutableCopyWithZone:(NSZone *)zone
{
    HTMLTokenAttributes *copy = [[HTMLTokenAttributes alloc] init];
    copy.href = _href;
    copy.bold = _bold;
    copy.italic = _italic;
    copy.underlined = _underlined;
    copy.list = _list;
    copy.nextListIndex = _nextListIndex;
    return copy;
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"bold: %i; italic: %i; underlined: %i; href: %@", _bold, _italic, _underlined, _href];
}

@end


@interface HTMLToken : NSObject

@property (nonatomic, strong) HTMLTokenAttributes *attributes;
@property (nonatomic, copy) NSString *text;

- (BOOL)isSpace;
- (BOOL)isLinebreak;
- (void)drawInRect:(CGRect)rect withStyles:(NSDictionary *)styles;

@end


@implementation HTMLToken

- (BOOL)isSpace
{
    return [_text isEqualToString:@" "];
}

- (BOOL)isLinebreak
{
    return [_text isEqualToString:@"\n"];
}

- (BOOL)isWhitespace
{
    return [self isSpace] || [self isLinebreak] || [_text isEqualToString:@"\u00A0"];
}

- (void)drawInRect:(CGRect)rect withStyles:(NSDictionary *)styles
{
    //select color
    [_attributes.href? styles[HTMLLinkColor]: styles[HTMLTextColor] setFill];
    
    //select font
    UIFont *font = styles[HTMLFont];
    if (_attributes.bold)
    {
        if (_attributes.italic)
        {
            font = [font boldItalicFontOfSize:font.pointSize];
        }
        else
        {
            font = [font boldFontOfSize:font.pointSize];
        }
    }
    else if (_attributes.italic)
    {
        font = [font italicFontOfSize:font.pointSize];
    }
    
    //draw text
    [_text drawInRect:rect withFont:font];
    
    //underline?
    if (_attributes.href? [styles[HTMLUnderlineLinks] boolValue]: _attributes.underlined)
    {
        CGContextRef c = UIGraphicsGetCurrentContext();
        CGContextFillRect(c, CGRectMake(rect.origin.x, rect.origin.y + font.pointSize + 1.0f, rect.size.width, 1.0f));
    }
}

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"%@", [self isLinebreak]? @"\\n": _text];
}

@end


@interface HTMLTokenizer : NSObject <NSXMLParserDelegate>

@property (nonatomic, strong) NSMutableArray *tokens;
@property (nonatomic, strong) NSMutableArray *stack;
@property (nonatomic, strong) NSMutableString *text;
@property (nonatomic, strong) NSString *html;

- (id)initWithHTML:(NSString *)html;

@end


@implementation HTMLTokenizer

- (NSCache *)cache
{
    static NSCache *cache = nil;
    if (cache == nil)
    {
        cache = [[NSCache alloc] init];
    }
    return cache;
}

- (id)initWithHTML:(NSString *)input
{
    if ((self = [super init]))
    {
        if (input)
        {
            //check cache
            if (!(_tokens = [[self cache] objectForKey:input]))
            {
                _stack = [[NSMutableArray alloc] init];
                _tokens = [[NSMutableArray alloc] init];
                _text = [[NSMutableString alloc] init];
                
                NSMutableString *html = [input mutableCopy];
                
                //sanitize entities
                [self replaceEntities:@{
                 @"nbsp":@"\u00A0", @"bull":@"•", @"copy":@"©", @"reg":@"®", @"deg":@"°",
                 @"ndash":@"–", @"mdash":@"—", @"apos":@"’", @"lsquo":@"‘", @"ldquo":@"“", @"rsquo":@"’", @"rdquo":@"”",
                 @"cent":@"¢", @"pound":@"£", @"euro":@"€", @"yen":@"¥"
                 } inString:html];
                [self replacePattern:@"&(?!(gt|lt|amp|quot|(#[0-9]+)));" inString:html withPattern:@""];
                [self replacePattern:@"&(?![a-z0-9]+;)" inString:html withPattern:@"&amp;"];
                [self replacePattern:@"<(?![/a-z])" inString:html withPattern:@"&lt;"];
                
                //sanitize tags
                [self replacePattern:@"([-_a-z]+)=([^\"'][^ >]+)" inString:html withPattern:@"$1=\"$2\""];
                [self replacePattern:@"<(area|base|br|col|command|embed|hr|img|input|link|meta|param|source)(\\s[^>]*)?>" inString:html withPattern:@"<$1/>"];
                
                //wrap in html tag
                html = [NSString stringWithFormat:@"<html>%@</html>", html];
                
                //parse
                _html = html;
                NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
                NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
                parser.delegate = self;
                [parser parse];
                
                //cache result
                [[self cache] setObject:_tokens forKey:input];
            }
        }
    }
    return self;
}

- (void)replacePattern:(NSString *)pattern inString:(NSMutableString *)string withPattern:(NSString *)replacement
{
    if (pattern && string)
    {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
        [regex replaceMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:replacement];
    }
}

- (void)replaceEntities:(NSDictionary *)entitiesAndReplacements inString:(NSMutableString *)string
{
    for (NSString *entity in entitiesAndReplacements)
    {
        [self replacePattern:[NSString stringWithFormat:@"&%@;", entity]
                    inString:string withPattern:entitiesAndReplacements[entity]];
    }
}

- (void)addText:(NSString *)text
{
    [_text appendString:text];
}

- (void)endText
{
    //collapse white space
    NSString *text = [_text stringByReplacingOccurrencesOfString:@"[\t\n\r ]+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, [_text length])];
    
    //split into words
    NSMutableArray *words = [[text componentsSeparatedByString:@" "] mutableCopy];
    
    //create tokens
    for (int i = 0; i < [words count]; i++)
    {
        NSString *word  = words[i];
        if (i > 0 && ![[_tokens lastObject] isWhitespace])
        {
            //space
            HTMLToken *token = [[HTMLToken alloc] init];
            token.attributes = [_stack lastObject];
            token.text = @" ";
            [_tokens addObject:token];
        }
        if ([word length])
        {
            //word
            HTMLToken *token = [[HTMLToken alloc] init];
            token.attributes = [_stack lastObject];
            token.text = word;
            [_tokens addObject:token];
        }
    }
    
    //clear text
    [_text setString:@""];
}

- (void)addLinebreaks:(NSInteger)count
{
    if ([_tokens count] && count)
    {
        HTMLToken *linebreak = [[HTMLToken alloc] init];
        linebreak.attributes = [_stack lastObject];
        linebreak.text = @"\n";
        
        //discard white-space before a line break
        if ([[_tokens lastObject] isSpace]) [_tokens removeLastObject];
        
        NSInteger last = [_tokens count] - 1;
        for (int i = last; i > last - count; i--)
        {
            if (i < 0 || ![_tokens[i] isLinebreak])
            {
                [_tokens addObject:linebreak];
            }
        }
    }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	[self endText];
    
    HTMLTokenAttributes *attributes = [[_stack lastObject] mutableCopy] ?: [[HTMLTokenAttributes alloc] init];
    elementName = [elementName lowercaseString];
    if ([elementName isEqualToString:@"a"])
    {
        attributes.href = attributeDict[@"href"];
    }
    else if ([elementName isEqualToString:@"b"] || [elementName isEqualToString:@"strong"])
    {
        attributes.bold = YES;
    }
    else if ([elementName isEqualToString:@"i"] || [elementName isEqualToString:@"em"])
    {
        attributes.italic = YES;
    }
    else if ([elementName isEqualToString:@"u"])
    {
        attributes.underlined = YES;
    }
    else if ([elementName rangeOfString:@"^h\\d$" options:NSRegularExpressionSearch].length == [elementName length])
    {
        [self addLinebreaks:2];
        
        attributes.bold = YES;
    }
    else if ([elementName isEqualToString:@"p"] || [elementName isEqualToString:@"div"])
    {
        [self addLinebreaks:2];
    }
    else if ([elementName isEqualToString:@"ul"] || [elementName isEqualToString:@"ol"])
    {
        [self addLinebreaks:2];
        
        attributes.list = YES;
        if ([elementName isEqualToString:@"ol"]) attributes.nextListIndex = 1;
    }
    else if ([elementName isEqualToString:@"li"])
    {
        [self addLinebreaks:1];
        
        attributes.list = NO;
        NSString *bullet = @"•";
        if (attributes.nextListIndex)
        {
            bullet = [NSString stringWithFormat:@"%i.", attributes.nextListIndex];
            ((HTMLTokenAttributes *)[_stack lastObject]).nextListIndex ++;
        }
        
        //add list bullet
        HTMLToken *token = [[HTMLToken alloc] init];
        token.attributes = [_stack lastObject];
        token.text = bullet;
        [_tokens addObject:token];
        
        //add space after bullet
        token = [[HTMLToken alloc] init];
        token.attributes = [_stack lastObject];
        token.text = @"";
        [_tokens addObject:token];
    }
	[_stack addObject:attributes];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    [self endText];
    
    elementName = [elementName lowercaseString];
    if ([elementName isEqualToString:@"br"])
    {
        //discard white-space before a line break
        if ([[_tokens lastObject] isSpace]) [_tokens removeLastObject];
        
        //this is a non-collapsing break, so we
        //won't use the addLinebreaks method
        HTMLToken *linebreak = [[HTMLToken alloc] init];
        linebreak.attributes = [_stack lastObject];
        linebreak.text = @"\n";
        [_tokens addObject:linebreak];
    }
    else if ([elementName isEqualToString:@"p"] || [elementName isEqualToString:@"div"] ||
             [elementName rangeOfString:@"^h(\\d$|r)" options:NSRegularExpressionSearch].length == [elementName length])
    {
        [self addLinebreaks:2];
    }
    else if ([elementName isEqualToString:@"ul"] || [elementName isEqualToString:@"ol"])
    {
        [self addLinebreaks:2];
    }
    else if ([elementName isEqualToString:@"li"])
    {
        [self addLinebreaks:1];
    }
    
	[_stack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[self addText:string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
	[self addText:[[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding]];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSLog(@"XML parser error: %@ input: %@", parseError, _html);
}

@end


#pragma mark -
#pragma mark HTML layout


@interface HTMLTokenLayout : NSObject

@property (nonatomic, copy) NSArray *tokens;
@property (nonatomic, copy) NSDictionary *styles;
@property (nonatomic, assign) CGFloat maxWidth;

@property (nonatomic, strong) NSMutableArray *frames;
@property (nonatomic, assign) CGSize size;

- (void)update;
- (void)drawAtPoint:(CGPoint)point;
- (HTMLToken *)tokenAtPosition:(CGPoint)point;

@end


@implementation HTMLTokenLayout

- (UIFont *)fontForToken:(HTMLToken *)token
{
    UIFont *font = _styles[HTMLFont];
    if (token.attributes.bold)
    {
        if (token.attributes.italic)
        {
            font = [font boldItalicFontOfSize:font.pointSize];
        }
        else
        {
            font = [font boldFontOfSize:font.pointSize];
        }
    }
    else if (token.attributes.italic)
    {
        font = [font italicFontOfSize:font.pointSize];
    }
    return font;
}

- (void)setTokens:(NSArray *)tokens
{
    _tokens = [tokens copy];
    [self setNeedsUpdate];
}

- (void)setAttributes:(NSDictionary *)attributes
{
    _styles = [attributes copy];
    [self setNeedsUpdate];
}

- (void)setMaxWidth:(CGFloat)maxWidth
{
    _maxWidth = maxWidth;
    [self setNeedsUpdate];
}

- (void)setNeedsUpdate
{
    _frames = nil;
}

- (void)update
{
    _frames = [[NSMutableArray alloc] init];
    _size = CGSizeZero;
    
    CGPoint position = CGPointZero;
    CGFloat lineHeight = 0.0f;
    for (int i = 0; i < [_tokens count]; i++)
    {
        HTMLToken *token = _tokens[i];
        UIFont *font = [self fontForToken:token];
        if ([token isLinebreak])
        {
            //newline
            if (lineHeight == 0.0f)
            {
                lineHeight = [@" " sizeWithFont:font].height;
            }
            position = CGPointMake(0.0f, position.y + lineHeight);
            lineHeight = 0.0f;
            
            //calculate frame and update size
            [_frames addObject:[NSValue valueWithCGRect:CGRectZero]];
            _size.height = position.y;
        }
        else if ([token isSpace])
        {
            //space
            CGSize size = [token.text sizeWithFont:font];
            if (position.x == 0.0f || position.x + size.width > _maxWidth)
            {
                //discard token
                size = CGSizeZero;
            }
            
            //calculate frame
            CGRect frame;
            frame.origin = position;
            frame.size = size;
            [_frames addObject:[NSValue valueWithCGRect:frame]];
            
            //prepare for next frame
            position.x += size.width;
            lineHeight = MAX(lineHeight, size.height);
            
            //update size
            _size.height = position.y + lineHeight;
            _size.width = MAX(_size.width, position.x);
        }
        else
        {
            //calculate size
            CGSize size = [token.text sizeWithFont:font];
            if (position.x + size.width > _maxWidth)
            {
                if (position.x > 0.0f)
                {
                    //discard previous space token
                    if (i > 0 && [[_tokens lastObject] isSpace])
                    {
                        CGRect frame = [_frames[i-1] CGRectValue];
                        frame.size = CGSizeZero;
                        _frames[i-1] = [NSValue valueWithCGRect:frame];
                    }
                    
                    //new line
                    position = CGPointMake(0.0f, position.y + lineHeight);
                    lineHeight = 0.0f;
                }
                else
                {
                    //truncate
                    size.width = _maxWidth;
                }
            }
            
            //calculate frame
            CGRect frame;
            frame.origin = position;
            frame.size = size;
            [_frames addObject:[NSValue valueWithCGRect:frame]];
            
            //prepare for next frame
            position.x += size.width;
            lineHeight = MAX(lineHeight, size.height);
            
            //update size
            _size.height = position.y + lineHeight;
            _size.width = MAX(_size.width, position.x);
        }
    }
}

- (void)drawAtPoint:(CGPoint)point
{
    if (!_frames) [self update];
    for (int i = 0 ; i < [_tokens count]; i ++)
    {
        CGRect frame = [_frames[i] CGRectValue];
        HTMLToken *token = _tokens[i];
        [token drawInRect:frame withStyles:_styles];
    }
}

- (HTMLToken *)tokenAtPosition:(CGPoint)point
{
    for (int i = 0; i < [_tokens count]; i++)
    {
        if (CGRectContainsPoint([_frames[i] CGRectValue], point))
        {
            return _tokens[i];
        }
    }
    return nil;
}

@end


@implementation NSString (HTMLRendering)

- (CGSize)sizeWithHtmlStyles:(NSDictionary *)styles forWidth:(CGFloat)width
{
    HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] initWithHTML:self];
    HTMLTokenLayout *layout = [[HTMLTokenLayout alloc] init];
    layout.tokens = tokenizer.tokens;
    layout.styles = styles;
    layout.maxWidth = width;
    [layout update];
    
    return layout.size;
}

- (void)drawHtmlInRect:(CGRect)rect withHtmlStyles:(NSDictionary *)styles
{
    HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] init];
    HTMLTokenLayout *layout = [[HTMLTokenLayout alloc] init];
    layout.tokens = tokenizer.tokens;
    layout.styles = styles;
    layout.maxWidth = rect.size.width;
    
    //TODO: crop to correct height
    [layout drawAtPoint:rect.origin];
}

@end


#pragma mark -
#pragma mark HTML label


@interface HTMLLabel () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) HTMLTokenLayout *layout;

@end


@implementation HTMLLabel

- (void)setUp
{
    _layout = [[HTMLTokenLayout alloc] init];
    _underlineLinks = YES;
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    tapGesture.numberOfTapsRequired = 1;
    tapGesture.numberOfTouchesRequired = 1;
    tapGesture.delegate = self;
    [self addGestureRecognizer:tapGesture];
    
    HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] initWithHTML:self.text];
    _layout.tokens = tokenizer.tokens;
    [self setNeedsDisplay];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        self.userInteractionEnabled = YES;
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)setText:(NSString *)text
{
    if (![super.text isEqualToString:text])
    {
        super.text = text;
        HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] initWithHTML:self.text];
        _layout.tokens = tokenizer.tokens;
        [self setNeedsDisplay];
    }
}

- (void)setFont:(UIFont *)font
{
    super.font = font;
    [self setNeedsDisplay];
}

- (void)setLinkColor:(UIColor *)linkColor
{
    _linkColor = linkColor;
    [self setNeedsDisplay];
}

- (void)setUnderlineLinks:(BOOL)underlineLinks
{
    _underlineLinks = underlineLinks;
    [self setNeedsDisplay];
}

- (NSDictionary *)htmlStyles
{
    return @{
HTMLFont: self.font,
HTMLTextColor: self.textColor ?: [UIColor blackColor],
HTMLLinkColor: self.linkColor ?: [UIColor blueColor],
HTMLUnderlineLinks: @(_underlineLinks)
    };
}

- (CGSize)sizeThatFits:(CGSize)size
{
    _layout.maxWidth = size.width;
    _layout.styles = [self htmlStyles];
    [_layout update];
    
    return _layout.size;
}

- (void)drawRect:(CGRect)rect
{
    _layout.maxWidth = self.bounds.size.width;
    _layout.styles = [self htmlStyles];
    [_layout drawAtPoint:CGPointZero];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    //play nice with others
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    //only recognize touches on links
    return [_layout tokenAtPosition:[touch locationInView:self]].attributes.href ? YES: NO;
}

- (void)tapped:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateRecognized)
    {
        HTMLToken *token = [_layout tokenAtPosition:[gesture locationInView:self]];
        if (token.attributes.href)
        {
            NSURL *URL = [NSURL URLWithString:token.attributes.href];
            if ([_delegate respondsToSelector:@selector(HTMLLabel:tappedLinkWithURL:bounds:)])
            {
                CGRect frame = [_layout.frames[[_layout.tokens indexOfObject:token]] CGRectValue];
                [_delegate HTMLLabel:self tappedLinkWithURL:URL bounds:frame];
            }
            BOOL openURL = YES;
            if ([_delegate respondsToSelector:@selector(HTMLLabel:shouldOpenURL:)])
            {
                openURL = [_delegate HTMLLabel:self shouldOpenURL:URL];
            }
            if (openURL) [[UIApplication sharedApplication] openURL:URL];
        }
    }
}

@end