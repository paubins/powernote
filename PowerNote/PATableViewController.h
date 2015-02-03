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
#import <CoreLocation/CoreLocation.h>

@interface PATableViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate, PATextViewControllerDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;


@end
