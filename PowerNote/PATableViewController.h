//
//  PATableViewController.h
//  PowerNote
//
//  Created by paubins on 1/10/15.
//  Copyright (c) 2015 paubins. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "PATextViewController.h"
#import "Note.h"

@interface PATableViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@end
