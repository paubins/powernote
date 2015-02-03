//
//  PATextViewController.h
//  PowerNote
//
//  Created by paubins on 1/11/15.
//  Copyright (c) 2015 paubins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Note.h"

@class PATextViewController;

@protocol PATextViewControllerDelegate <NSObject>

- (void)textViewController:(PATextViewController *)controller didEndEditing:(BOOL)endEditing withNote:(NSString *)noteText;

@end

@interface PATextViewController : UIViewController

@property (nonatomic, strong) Note *note;
@property (nonatomic, weak) id<PATextViewControllerDelegate> delegate;
@property (strong, nonatomic) IBOutlet UITextView *noteTextView;


@end
