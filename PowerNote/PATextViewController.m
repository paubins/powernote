//
//  PATextViewController.m
//  PowerNote
//
//  Created by paubins on 1/11/15.
//  Copyright (c) 2015 paubins. All rights reserved.
//

#import "PATextViewController.h"
#import "Note.h"

@interface PATextViewController ()

@end

@implementation PATextViewController {
    BOOL _keyboardShown;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    _keyboardShown = NO;
    
    if (self.note.answer != nil && ![self.note.answer isEqualToString:@""]) {
        UIBarButtonItem *leftBarButton = [[UIBarButtonItem alloc] initWithTitle:@"Open Answer" style:UIBarButtonItemStylePlain target:self action:@selector(openAnswer)];
        self.navigationItem.rightBarButtonItem = leftBarButton;
    }
    
    if (self.note.category != nil) {
        self.navigationItem.title = self.note.category;
    }
    
    UITextView *textView = (UITextView *)self.view;
    textView.text = self.note.note;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

- (void)openAnswer {
    NSLog(@"opening answer");
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.note.answer]];
}

- (void)viewDidDisappear:(BOOL)animated
{
    id<PATextViewControllerDelegate> delegate = self.delegate;
    if ([delegate conformsToProtocol:@protocol(PATextViewControllerDelegate)]) {
        [delegate textViewController:self didEndEditing:YES withNote:self.noteTextView.text];
    }
}

- (void)keyboardWasShown:(NSNotification*)notification {
    if (_keyboardShown) return;
    
    NSDictionary* info = [notification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - keyboardSize.height);
    
    _keyboardShown = YES;
}

- (void)keyboardWillBeHidden:(NSNotification*)notification {
    _keyboardShown = NO;
    self.noteTextView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
}

- (void)textViewDidChange:(UITextView *)textView {
    [textView scrollRangeToVisible:[textView selectedRange]];
}

@end
