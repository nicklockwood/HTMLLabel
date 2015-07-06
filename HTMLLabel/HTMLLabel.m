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


//temporary fix
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"


NSString *const HTMLBold = @"bold";
NSString *const HTMLItalic = @"italic";
NSString *const HTMLUnderline = @"underline";
NSString *const HTMLFont = @"font";
NSString *const HTMLTextSize = @"textSize";
NSString *const HTMLTextColor = @"textColor";
NSString *const HTMLTextAlignment = @"textAlignment";


#pragma mark -
#pragma mark Fonts


@implementation UIFont (Variants)

- (BOOL)fontWithName:(NSString *)name hasTrait:(NSString *)trait
{
    name = [name lowercaseString];
    if ([name rangeOfString:trait].location != NSNotFound)
    {
        return YES;
    }
    else if ([trait isEqualToString:@"oblique"])
    {
        return [name rangeOfString:@"italic"].location != NSNotFound;
    }
    return NO;
}

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
    if ([familyName hasPrefix:@".Helvetica Neue"])
    {
        familyName = @"Helvetica Neue";
    }
    
    for (NSString *name in [UIFont fontNamesForFamilyName:familyName])
    {
        BOOL match = YES;
        for (NSString *trait in blacklist)
        {
            if ([self fontWithName:name hasTrait:trait])
            {
                match = NO;
                break;
            }
        }
        for (NSString *trait in traits)
        {
            if (![self fontWithName:name hasTrait:trait])
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
#pragma mark HTML token


@interface HTMLTokenAttributes : NSObject <NSMutableCopying>

@property (nonatomic, copy) NSString *href;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSArray *classNames;
@property (nonatomic, strong) HTMLTokenAttributes *parent;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL list;
@property (nonatomic, assign) BOOL bullet;
@property (nonatomic, assign) NSInteger listLevel;
@property (nonatomic, assign) NSInteger nextListIndex;

@end


@class HTMLStyles;


@interface HTMLToken : NSObject

@property (nonatomic, strong) HTMLTokenAttributes *attributes;
@property (nonatomic, copy) NSString *text;

- (BOOL)isSpace;
- (BOOL)isLinebreak;
- (CGSize)sizeWithStyles:(HTMLStyles *)styles;
- (void)drawInRect:(CGRect)rect withStyles:(HTMLStyles *)styles;

@end


#pragma mark -
#pragma mark HTML styles


@interface HTMLStyles : NSObject <NSCopying>

@property (nonatomic, strong, readonly) UIFont *font;
@property (nonatomic, strong, readonly) UIColor *textColor;
@property (nonatomic, assign, readonly) CGFloat textSize;
@property (nonatomic, assign, readonly) NSTextAlignment textAlignment;
@property (nonatomic, assign, readonly, getter = isBold) BOOL bold;
@property (nonatomic, assign, readonly, getter = isItalic) BOOL italic;
@property (nonatomic, assign, readonly, getter = isUnderlined) BOOL underline;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;
- (HTMLStyles *)stylesByAddingStylesFromDictionary:(NSDictionary *)dict;
- (HTMLStyles *)stylesByAddingStyles:(HTMLStyles *)styles;

@end


@interface HTMLStyles ()

@property (nonatomic, copy) NSDictionary *styles;

@end


@implementation HTMLStyles

- (id)initWithDictionary:(NSDictionary *)dict
{
    if ((self = [super init]))
    {
        _styles = [dict copy];
    }
    return self;
}

- (UIFont *)font
{
    UIFont *font = _styles[HTMLFont];
    if ([font isKindOfClass:[NSString class]])
    {
        font = [UIFont fontWithName:(NSString *)font size:17.0f];
    }
    NSInteger pointSize = [_styles[HTMLTextSize] floatValue] ?: font.pointSize;
    if (self.bold)
    {
        if (self.italic)
        {
            font = [font boldItalicFontOfSize:pointSize];
        }
        else
        {
            font = [font boldFontOfSize:pointSize];
        }
    }
    else if (self.italic)
    {
        font = [font italicFontOfSize:pointSize];
    }
    else
    {
        font = [font fontWithSize:pointSize];
    }
    return font;
}

- (UIColor *)textColor
{
    UIColor *textColor = _styles[HTMLTextColor];
    if ([textColor isKindOfClass:[NSString class]])
    {
        SEL selector = NSSelectorFromString(@"colorWithString:");
        if ([UIColor respondsToSelector:selector])
        {
     
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warc-performSelector-leaks"
            
            textColor = [[UIColor class] performSelector:selector withObject:textColor];
            
#pragma GCC diagnostic pop
            
        }
        else
        {
            [NSException raise:@"HTMLLabelError" format:@"Setting a color by string requires the ColorUtils library to be included in your project. Get it from here: https://github.com/nicklockwood/ColorUtils"];
        }
    }
    return textColor;
}

- (CGFloat)textSize
{
    return [_styles[HTMLTextSize] floatValue] ?: [_styles[HTMLFont] pointSize];
}

- (NSTextAlignment)textAlignment
{
    return [_styles[HTMLTextAlignment] integerValue];
}

- (BOOL)isBold
{
    return [_styles[HTMLBold] boolValue];
}

- (BOOL)isItalic
{
    return [_styles[HTMLItalic] boolValue];
}

- (BOOL)isUnderlined
{
    return [_styles[HTMLUnderline] boolValue];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    return [_styles copy];
}

- (HTMLStyles *)stylesByAddingStylesFromDictionary:(NSDictionary *)dict
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:_styles];
    [result addEntriesFromDictionary:dict];
    return [[HTMLStyles alloc] initWithDictionary:result];
}

- (HTMLStyles *)stylesByAddingStyles:(HTMLStyles *)styles
{
    return [self stylesByAddingStylesFromDictionary:[styles dictionaryRepresentation]];
}

- (NSString *)description
{
    return [[self dictionaryRepresentation] description];
}

@end


@interface HTMLStyleSelector : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *tag;
@property (nonatomic, copy, readonly) NSArray *classNames;
@property (nonatomic, copy, readonly) NSArray *pseudoSelectors;

- (id)initWithString:(NSString *)selectorString;
- (NSString *)stringRepresentation;
- (BOOL)matchesTokenAttributes:(HTMLTokenAttributes *)attributes;

@end


@interface HTMLStyleSelector ()

@property (nonatomic, copy) NSString *selectorString;

@end


@implementation HTMLStyleSelector

- (id)initWithString:(NSString *)selectorString
{
    if ((self = [super init]))
    {
        _selectorString = selectorString;
        
        //parse pseudo selectors
        NSArray *parts = [selectorString componentsSeparatedByString:@":"];
        NSInteger count = [parts count];
        if (count > 0)
        {
            selectorString = parts[0];
            if (count > 1)
            {
                _pseudoSelectors = [parts subarrayWithRange:NSMakeRange(1, count - 1)];
            }
        }
        
        //parse class names
        parts = [selectorString componentsSeparatedByString:@"."];
        count = [parts count];
        if (count > 0)
        {
            _tag = parts[0];
            if (count > 1)
            {
                _classNames = [parts subarrayWithRange:NSMakeRange(1, count - 1)];
            }
        }
        
        //TODO: more
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)stringRepresentation
{
    return _selectorString;
}

- (NSString *)description
{
    return [self stringRepresentation];
}

- (NSUInteger)hash
{
    return [[self stringRepresentation] hash];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[HTMLStyleSelector class]])
    {
        return [[self stringRepresentation] isEqualToString:[object stringRepresentation]];
    }
    else if ([object isKindOfClass:[NSString class]])
    {
        return [[self stringRepresentation] isEqualToString:object];
    }
    return NO;
}

- (BOOL)matchesTokenAttributes:(HTMLTokenAttributes *)attributes
{
    //check tag
    if (![_tag length] || [_tag isEqualToString:@"*"] || [attributes.tag isEqualToString:_tag])
    {
        //check classes
        for (NSString *className in _classNames)
        {
            if (![attributes.classNames containsObject:className])
            {
                return NO;
            }
        }
        for (NSString *pseudo in _pseudoSelectors)
        {
            if ([pseudo isEqualToString:@"active"] && !attributes.active)
            {
                return NO;
            }
        }
        return YES;
    }
    return NO;
}

@end


@interface HTMLStylesheet : NSObject <NSCopying>

@property (nonatomic, copy) NSArray *selectors;
@property (nonatomic, copy) NSDictionary *stylesBySelector;

@end


@implementation HTMLStylesheet

+ (HTMLStylesheet *)defaultStylesheet
{
    static HTMLStylesheet *defaultStylesheet = nil;
    if (defaultStylesheet == nil)
    {
        NSDictionary *styles = @{
        @"html": @{HTMLTextColor: [UIColor blackColor], HTMLFont:[UIFont systemFontOfSize:17.0f]},
        @"a": @{HTMLTextColor: [UIColor blueColor], HTMLUnderline: @YES},
        @"a:active": @{HTMLTextColor: [UIColor redColor]},
        @"b,strong,h1,h2,h3,h4,h5,h6": @{HTMLBold: @YES},
        @"i,em": @{HTMLItalic: @YES},
        @"u": @{HTMLUnderline: @YES}
        };
        defaultStylesheet = [[HTMLStylesheet alloc] initWithDictionary:styles];
    }
    return defaultStylesheet;
}

+ (instancetype)stylesheetWithDictionary:(NSDictionary *)dictionary
{
    return [[self alloc] initWithDictionary:dictionary];
}

+ (NSDictionary *)dictionaryByMergingStyleDictionaries:(NSArray *)dictionaries
{
    HTMLStylesheet *stylesheet = [[HTMLStylesheet alloc] init];
    for (NSDictionary *dictionary in dictionaries)
    {
        [stylesheet addStylesFromDictionary:dictionary];
    }
    return [stylesheet dictionaryRepresentation];
}

- (void)addStylesFromDictionary:(NSDictionary *)dictionary
{
    for (NSString *key in dictionary)
    {
        [self addStyles:dictionary[key] forSelector:key];
    }
}

- (void)addStyles:(id)styles forSelector:(id)selector
{
    if ([selector isKindOfClass:[NSString class]])
    {
        NSArray *selectors = [selector componentsSeparatedByString:@","];
        if ([selectors count] > 1)
        {
            for (NSString *selector in selectors)
            {
                [self addStyles:styles forSelector:selector];
            }
            return;
        }
        selector = [[HTMLStyleSelector alloc] initWithString:selector];
    }
    HTMLStyles *existingStyles = [_stylesBySelector objectForKey:selector];
    if (existingStyles)
    {
        if (![styles isKindOfClass:[NSDictionary class]])
        {
            styles = [existingStyles stylesByAddingStyles:styles];
        }
        else
        {
            styles = [existingStyles stylesByAddingStylesFromDictionary:styles];
        }
    }
    else
    {
        [(NSMutableArray *)_selectors addObject:selector];
        if ([styles isKindOfClass:[NSDictionary class]])
        {
            styles = [[HTMLStyles alloc] initWithDictionary:styles];
        }
    }
    [(NSMutableDictionary *)_stylesBySelector setObject:styles forKey:selector];
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    if ((self = [self init]))
    {
        [self addStylesFromDictionary:dictionary];
    }
    return self;
}

- (id)init
{
    if ((self = [super init]))
    {
        _selectors = [NSMutableArray array];
        _stylesBySelector = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *stylesheet = [NSMutableDictionary dictionary];
    for (HTMLStyleSelector *selector in _selectors)
    {
        HTMLStyles *styles = [self stylesForSelector:selector];
        [stylesheet setObject:[styles dictionaryRepresentation]
                       forKey:[selector stringRepresentation]];
    }
    return stylesheet;
}

- (HTMLStylesheet *)stylesheetByaddingStyles:(NSDictionary *)styles forSelector:(NSString *)selector
{
    HTMLStylesheet *stylesheet = [[HTMLStylesheet alloc] initWithDictionary:[self dictionaryRepresentation]];
    [stylesheet addStyles:styles forSelector:selector];
    return stylesheet;
}

- (HTMLStylesheet *)stylesheetByaddingStylesFromDictionary:(NSDictionary *)dictionary
{
    HTMLStylesheet *stylesheet = [[HTMLStylesheet alloc] initWithDictionary:[self dictionaryRepresentation]];
    [stylesheet addStylesFromDictionary:dictionary];
    return stylesheet;
}

- (HTMLStylesheet *)stylesheetByaddingStyles:(HTMLStylesheet *)styles
{
    HTMLStylesheet *stylesheet = [[HTMLStylesheet alloc] initWithDictionary:[self dictionaryRepresentation]];
    [stylesheet addStylesFromDictionary:[styles dictionaryRepresentation]];
    return stylesheet;
}

- (HTMLStyles *)stylesForSelector:(id)selector
{
    return [_stylesBySelector objectForKey:selector];
}

- (HTMLStyles *)stylesForToken:(HTMLToken *)token
{
    HTMLStyles *allStyles = nil;
    HTMLTokenAttributes *attributes = token.attributes;
    while (attributes)
    {
        HTMLStyles *styles = [[HTMLStyles alloc] init];
        for (HTMLStyleSelector *selector in _selectors)
        {
            if ([selector matchesTokenAttributes:attributes])
            {
                styles = [styles stylesByAddingStyles:[self stylesForSelector:selector]];
            }
        }
        allStyles = [styles stylesByAddingStyles:allStyles];
        attributes = attributes.parent;
    }
    return allStyles;
}

- (NSString *)description
{
    return [[self dictionaryRepresentation] description];
}

@end


#pragma mark -
#pragma mark HTML parsing


@implementation HTMLTokenAttributes

- (id)mutableCopyWithZone:(NSZone *)zone
{
    HTMLTokenAttributes *copy = [[HTMLTokenAttributes alloc] init];
    copy.href = _href;
    copy.tag = _tag;
    copy.classNames = _classNames;
    copy.list = _list;
    copy.listLevel = _listLevel;
    copy.nextListIndex = _nextListIndex;
    return copy;
}

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
    return [self isSpace] || [self isLinebreak] || [_text isEqualToString:@"\u00A0"] || _attributes.bullet;
}

- (void)drawInRect:(CGRect)rect withStyles:(HTMLStyles *)styles
{
    //set color
    [styles.textColor setFill];
    
    //draw text
    [_text drawInRect:rect withFont:styles.font];
    
    //underline?
    if (styles.underline)
    {
        CGContextRef c = UIGraphicsGetCurrentContext();
        CGContextFillRect(c, CGRectMake(rect.origin.x, rect.origin.y + styles.font.pointSize + 1.0f, rect.size.width, 1.0f));
    }
}

- (CGSize)sizeWithStyles:(HTMLStyles *)styles
{
    return [_text sizeWithFont:styles.font];
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
                 @"cent":@"¢", @"pound":@"£", @"euro":@"€", @"yen":@"¥", @"ntilde":@"\u00F1", @"#39":@"'"
                 } inString:html];
                [self replacePattern:@"&(?!(gt|lt|amp|quot|(#[0-9]+)));" inString:html withPattern:@""];
                [self replacePattern:@"&(?![a-z0-9]+;)" inString:html withPattern:@"&amp;"];
                [self replacePattern:@"<(?![/a-z])" inString:html withPattern:@"&lt;"];
                
                //sanitize tags
                [self replacePattern:@"([-_a-z]+)=([^\"'][^ >]+)" inString:html withPattern:@"$1=\"$2\""];
                [self replacePattern:@"<(area|base|br|col|command|embed|hr|img|input|link|meta|param|source)(\\s[^>]*)?>" inString:html withPattern:@"<$1/>"];
                
                //wrap in html tag
                _html = [NSString stringWithFormat:@"<html>%@</html>", html];
                
                //parse
                NSData *data = [_html dataUsingEncoding:NSUTF8StringEncoding];
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
        for (NSInteger i = last; i > last - count; i--)
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
    attributes.parent = [_stack lastObject];
    elementName = [elementName lowercaseString];
    attributes.tag = elementName;
    attributes.classNames = [attributeDict[@"class"] componentsSeparatedByString:@" "];
    
    if ([elementName isEqualToString:@"a"])
    {
        attributes.href = attributeDict[@"href"];
    }
    else if ([elementName rangeOfString:@"^h\\d$" options:NSRegularExpressionSearch].length == [elementName length])
    {
        [self addLinebreaks:2];
    }
    else if ([elementName isEqualToString:@"p"] || [elementName isEqualToString:@"div"])
    {
        [self addLinebreaks:2];
    }
    else if ([elementName isEqualToString:@"ul"] || [elementName isEqualToString:@"ol"])
    {
        [self addLinebreaks:2];
        
        attributes.list = YES;
        attributes.listLevel ++;
        if ([elementName isEqualToString:@"ol"]) attributes.nextListIndex = 1;
    }
    else if ([elementName isEqualToString:@"li"])
    {
        [self addLinebreaks:1];
        
        attributes.list = NO;
        NSString *bullet = @"•";
        if (attributes.nextListIndex)
        {
            bullet = [NSString stringWithFormat:@"%@.", @(attributes.nextListIndex)];
            ((HTMLTokenAttributes *)[_stack lastObject]).nextListIndex ++;
        }
        
        //add list bullet
        HTMLToken *token = [[HTMLToken alloc] init];
        token.attributes = [[_stack lastObject] mutableCopy];
        token.attributes.parent = [_stack lastObject];
        token.attributes.bullet = YES;
        token.text = bullet;
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
    [self endText];
    
#ifdef DEBUG
    
    [self addLinebreaks:2];
    [self addText:[parseError localizedDescription]];
    [self endText];
    
    NSLog(@"XML parser error: %@", parseError);
    
#endif
    
}

@end


#pragma mark -
#pragma mark HTML layout


@interface HTMLLayout : NSObject

@property (nonatomic, copy) NSArray *tokens;
@property (nonatomic, copy) HTMLStylesheet *stylesheet;
@property (nonatomic, assign) CGFloat maxWidth;

//generated properties
@property (nonatomic, strong, readonly) NSMutableArray *frames;
@property (nonatomic, assign, readonly) CGSize size;

- (void)update;
- (void)drawAtPoint:(CGPoint)point;
- (HTMLToken *)tokenAtPosition:(CGPoint)point;

@end


@interface HTMLLayout ()

@property (nonatomic, assign) CGSize size;

@end


@implementation HTMLLayout

- (id)init
{
    if ((self = [super init]))
    {
        _stylesheet = [HTMLStylesheet defaultStylesheet];
    }
    return self;
}

- (void)setTokens:(NSArray *)tokens
{
    _tokens = [tokens copy];
    [self setNeedsUpdate];
}

- (void)setStylesheet:(HTMLStylesheet *)stylesheet
{
    _stylesheet = [[HTMLStylesheet defaultStylesheet] stylesheetByaddingStyles:stylesheet];
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
    NSInteger lineStartIndex = 0;
    BOOL newLine = YES;
    BOOL wrapped = NO;
    
    NSInteger tokenCount = [_tokens count];
    for (NSInteger i = 0; i < tokenCount; i++)
    {
        HTMLToken *token = _tokens[i];
        HTMLStyles *styles = [_stylesheet stylesForToken:token];
        
        CGFloat oneEm = [@"m" sizeWithFont:styles.font].width;
        CGFloat indent = oneEm * 3;
        CGFloat padding = oneEm;
        
        CGSize size = [token sizeWithStyles:styles];
        if ([token isLinebreak])
        {
            //newline
            lineHeight = MAX(lineHeight, size.height);
            position = CGPointMake(0.0f, position.y + lineHeight);
            lineHeight = 0.0f;
            newLine = YES;
            
            //calculate frame and update size
            [_frames addObject:[NSValue valueWithCGRect:CGRectZero]];
            _size.height = position.y;
        }
        else if ([token isSpace])
        {
            //space
            if (newLine || position.x + size.width > _maxWidth)
            {
                //discard token
                size = CGSizeZero;
            }
            
            //calculate frame
            CGRect frame;
            frame.origin = position;
            frame.origin.x += token.attributes.listLevel * indent;
            frame.size = size;
            [_frames addObject:[NSValue valueWithCGRect:frame]];
            
            //prepare for next frame
            position.x += size.width;
            lineHeight = MAX(lineHeight, size.height);
        }
        else
        {
            if (newLine)
            {
                //indent list
                position.x = token.attributes.listLevel * indent;
            }
            
            //calculate size
            if (position.x + size.width > _maxWidth)
            {
                if (!newLine)
                {
                    //discard previous space token
                    if (i > 0 && [_tokens[i-1] isSpace])
                    {
                        CGRect frame = [_frames[i-1] CGRectValue];
                        frame.size = CGSizeZero;
                        _frames[i-1] = [NSValue valueWithCGRect:frame];
                    }
                    
                    //new line
                    position = CGPointMake(token.attributes.listLevel * indent, position.y + lineHeight);
                    lineHeight = 0.0f;
                    wrapped = YES;
                }
                else
                {
                    //truncate
                    size.width = _maxWidth;
                }
            }
            
            //handle bullets
            if (token.attributes.bullet)
            {
                size.width += padding;
                if (token.attributes.listLevel)
                {
                    position.x -= size.width;
                }
            }
            
            //calculate frame
            CGRect frame;
            frame.origin = position;
            frame.size = size;
            [_frames addObject:[NSValue valueWithCGRect:frame]];
            
            //update size
            _size.height = MAX(_size.height, position.y + size.height);
            _size.width = MAX(_size.width, position.x + size.width);
            
            //prepare for next frame
            lineHeight = MAX(lineHeight, size.height);
            position.x += size.width;
            newLine = NO;
        }
        
        if (newLine || wrapped || i == tokenCount - 1)
        {
            //determine if adjustment is needed
            NSInteger lastIndex = (wrapped || newLine)? i - 1: i;
            NSTextAlignment alignment = [_stylesheet stylesForToken:_tokens[lineStartIndex]].textAlignment;
            if (self.maxWidth && alignment != NSTextAlignmentLeft)
            {
                //adjust alignment
                CGRect frame = [_frames[lastIndex] CGRectValue];
                CGFloat lineWidth = frame.origin.x + frame.size.width - [_frames[lineStartIndex] CGRectValue].origin.x;
                CGFloat offset = 0.0f;
                if (alignment == NSTextAlignmentRight)
                {
                    offset = self.maxWidth - lineWidth;
                }
                else if (alignment == NSTextAlignmentCenter)
                {
                    offset = (self.maxWidth - lineWidth) / 2;
                }
                else
                {
                    //TODO: other alignment options
                }
                
                for (NSInteger j = lineStartIndex; j <= lastIndex; j++)
                {
                    CGRect frame = [_frames[j] CGRectValue];
                    frame.origin.x += offset;
                    _frames[j] = [NSValue valueWithCGRect:frame];
                }
            }
            
            //prepare for next line
            if (newLine)
            {
                lineStartIndex = i + 1;
            }
            else if (wrapped)
            {
                lineStartIndex = i;
                wrapped = NO;
            }
        }
    }
}

- (CGSize)size
{
    if (!_frames) [self update];
    return _size;
}

- (void)drawAtPoint:(CGPoint)point
{
    if (!_frames) [self update];
    for (int i = 0 ; i < [_tokens count]; i ++)
    {
        CGRect frame = [_frames[i] CGRectValue];
        HTMLToken *token = _tokens[i];
        [token drawInRect:frame withStyles:[_stylesheet stylesForToken:token]];
    }
}

- (HTMLToken *)tokenAtPosition:(CGPoint)point
{
    if (!_frames) [self update];
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

- (CGSize)sizeForWidth:(CGFloat)width withHTMLStyles:(NSDictionary *)stylesheet
{
    HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] initWithHTML:self];
    HTMLLayout *layout = [[HTMLLayout alloc] init];
    layout.tokens = tokenizer.tokens;
    layout.stylesheet = [HTMLStylesheet stylesheetWithDictionary:stylesheet];
    layout.maxWidth = width;
    return layout.size;
}

- (void)drawInRect:(CGRect)rect withHTMLStyles:(NSDictionary *)stylesheet
{
    HTMLTokenizer *tokenizer = [[HTMLTokenizer alloc] init];
    HTMLLayout *layout = [[HTMLLayout alloc] init];
    layout.tokens = tokenizer.tokens;
    layout.stylesheet = [HTMLStylesheet stylesheetWithDictionary:stylesheet];
    layout.maxWidth = rect.size.width;
    
    //TODO: crop to correct height
    [layout drawAtPoint:rect.origin];
}

@end


#pragma mark -
#pragma mark HTML label


@interface HTMLLabel ()

@property (nonatomic, strong) HTMLLayout *layout;

@end


@implementation HTMLLabel

- (void)setUp
{
    _layout = [[HTMLLayout alloc] init];
    self.stylesheet = nil;

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
    self.stylesheet = [HTMLStylesheet dictionaryByMergingStyleDictionaries:@[_stylesheet ?: @{}, @{@"html": @{HTMLFont: self.font ?: [UIFont systemFontOfSize:17.0f]}}]];
}

- (void)setTextColor:(UIColor *)textColor
{
    super.textColor = textColor;
    self.stylesheet = [HTMLStylesheet dictionaryByMergingStyleDictionaries:@[_stylesheet ?: @{}, @{@"html": @{HTMLTextColor: self.textColor ?: [UIColor blackColor]}}]];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    super.textAlignment = textAlignment;
    self.stylesheet = [HTMLStylesheet dictionaryByMergingStyleDictionaries:@[_stylesheet ?: @{}, @{@"html": @{HTMLTextAlignment: @(textAlignment)}}]];
}

- (void)setStylesheet:(NSDictionary *)stylesheet
{
    _stylesheet = [HTMLStylesheet dictionaryByMergingStyleDictionaries:@[@{@"html": @{
                                                              HTMLFont: self.font ?: [UIFont systemFontOfSize:17.0f],
                                                              HTMLTextColor: self.textColor ?: [UIColor blackColor],
                                                              HTMLTextAlignment: @(self.textAlignment)
                                                              }}, stylesheet ?: @{}]];
    
    _layout.stylesheet = [HTMLStylesheet stylesheetWithDictionary:_stylesheet];

    HTMLStyles *styles = [_layout.stylesheet stylesForSelector:@"html"];
    super.font = styles.font ?: self.font;
    super.textColor = styles.textColor ?: self.textColor;
    super.textAlignment = styles.textAlignment;
    [self setNeedsDisplay];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    _layout.maxWidth = size.width;
    return _layout.size;
}

- (void)drawRect:(CGRect)rect
{
    _layout.maxWidth = self.bounds.size.width;
    [_layout drawAtPoint:CGPointZero];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [_layout tokenAtPosition:[touch locationInView:self]].attributes.active = YES;
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[_layout valueForKeyPath:@"tokens.attributes"] makeObjectsPerformSelector:@selector(setActive:) withObject:0];
    [self setNeedsDisplay];
    
    UITouch *touch = [touches anyObject];
    HTMLToken *token = [_layout tokenAtPosition:[touch locationInView:self]];
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

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [[_layout valueForKeyPath:@"tokens.attributes"] makeObjectsPerformSelector:@selector(setActive:) withObject:0];
    [self setNeedsDisplay];
}

@end
