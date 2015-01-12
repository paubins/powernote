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

@implementation PATextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITextView *textView = (UITextView *)self.view;
    textView.text = self.note.note;
    
    [textView becomeFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated
{
    UITextView *textView = (UITextView *)self.view;
    NSString *newNote = textView.text;
    if ([newNote isEqualToString:self.note.note]) return;
    
    NSManagedObjectContext *context = [self managedObjectContext];
    
    // Create a new managed object
    [self.note setValue:newNote forKey:@"note"];
    [self.note setValue:[NSDate date] forKey:@"date"];
    
    NSError *error = nil;
    // Save the object to persistent store
    if (![context save:&error]) {
        NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (NSManagedObjectContext *)managedObjectContext
{
    NSManagedObjectContext *context = nil;
    id delegate = [[UIApplication sharedApplication] delegate];
    if ([delegate performSelector:@selector(managedObjectContext)]) {
        context = [delegate managedObjectContext];
    }
    return context;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
