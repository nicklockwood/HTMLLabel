//
//  FirstViewController.m
//  HTMLLabelTests
//
//  Created by Nick Lockwood on 19/11/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import "ParsingViewController.h"
#import "HTMLLabel.h"


@interface ParsingViewController () <UITextViewDelegate, UIActionSheetDelegate>

@property (nonatomic, weak) IBOutlet UINavigationBar *navigationBar;
@property (nonatomic, weak) IBOutlet UITextView *inputField;
@property (nonatomic, weak) IBOutlet HTMLLabel *outputField;
@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;

@end


@implementation ParsingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
    {
        self.title = @"Parsing";
        self.tabBarItem.image = [UIImage imageNamed:@"tab"];
    }
    return self;
}

- (void)dismissKeyboard
{
    [_inputField resignFirstResponder];
    self.navigationBar.topItem.leftBarButtonItem = nil;
}

- (IBAction)selectInput
{
    [[[UIActionSheet alloc] initWithTitle:@"Select input" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete all input" otherButtonTitles:@"Lorem ipsum", @"Ordered list", @"Unordered list", @"Naked list", @"Links", @"Broken tags", @"Styles", nil] showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        _outputField.stylesheet = nil;
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            _inputField.text = nil;
        }
        else
        {
            switch (buttonIndex)
            {
                case 1:
                {
                    _inputField.text = @"Lorem ipsum dolor sit er elit lamet, consectetaur cillium adipisicing pecu, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Nam liber te conscient to factor tum poen legum odioque civiuda.";
                    break;
                }
                case 2:
                {
                    _inputField.text = @"Lorem ipsum <ol> <li> dolor sit er elit lamet, </li> <li> consectetaur cillium adipisicing pecu, <ol> <li> sed do eiusmod tempor incididunt ut labore </li> </ol> </li> </ol> et dolore magna aliqua.";
                    break;
                }
                case 3:
                {
                    _inputField.text = @"Lorem ipsum <ul> <li> dolor sit er elit lamet, </li> <li> consectetaur cillium adipisicing pecu, <ul> <li>sed do eiusmod tempor incididunt </li> </ul> </li> </ul> ut labore et dolore magna aliqua.";
                    break;
                }
                case 4:
                {
                    _inputField.text = @"Lorem ipsum <li> dolor sit er elit lamet, </li> <li> consectetaur cillium adipisicing pecu, sed <li>do eiusmod tempor incididunt</li></li> ut labore et dolore magna aliqua.";
                    break;
                }
                case 5:
                {
                    _inputField.text = @"Lorem ipsum <a href=\"http://apple.com\"> dolor sit er elit lamet, </a> consectetaur cillium adipisicing pecu, sed do eiusmod tempor <a href=\"http://github.com\">incididunt ut labore et dolore magna aliqua.</a> Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";
                    break;
                }
                case 6:
                {
                    _inputField.text = @"Lorem >ipsum dolor sit < er elit lamet, consectetaur cillium adipisicing pecu, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";
                    break;
                }
                case 7:
                {
                    _outputField.stylesheet = @{
                    @"html": @{HTMLTextSize: @20},
                    @"a": @{HTMLFont: @"Georgia", HTMLTextColor: [UIColor redColor]},
                    @".green": @{HTMLTextColor: [UIColor greenColor], HTMLBold: @YES}
                    };
                    
                    _inputField.text = @"Lorem <a href=\"foo\">ipsum dolor sit er elit</a> lamet, consectetaur cillium adipisicing pecu, sed do eiusmod tempor <i>incididunt</i> ut labore et dolore magna aliqua. <b>Ut enim</b> ad minim veniam, <span class=\"green\">quis nostrud</span> exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Nam liber te conscient to factor tum poen legum odioque civiuda.";
                    break;
                }
                default:
                {
                    break;
                }
            }
            
        }
        [self update];
    }
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    self.navigationBar.topItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)];
}

- (void)update
{
    _outputField.text = _inputField.text;
    CGRect frame = _outputField.frame;
    frame.size.height = [_outputField sizeThatFits:CGSizeMake(frame.size.width, INFINITY)].height;
    _outputField.frame = frame;
    _scrollView.contentSize = CGSizeMake(_scrollView.contentSize.width, frame.size.height + 20);
}
							
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update) name:UITextViewTextDidChangeNotification object:_inputField];
    
    [self update];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:_inputField];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
