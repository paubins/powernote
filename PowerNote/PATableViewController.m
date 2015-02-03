//
//  PATableViewController.m
//  PowerNote
//
//  Created by paubins on 1/10/15.
//  Copyright (c) 2015 paubins. All rights reserved.
//

#import "PATableViewController.h"

static NSString *kNewNoteSegueIdentifier = @"NewNoteSeque";
static NSString *kUpdateNoteSegueIdentifier = @"UpdateNoteSegue";
static NSString *kNoteCellIdentifier = @"NoteCell";

typedef NS_ENUM(NSUInteger, ActionType) {
    kUpdate = 0,
    kDelete
};

@implementation PATableViewController {
    NSTimer *_currentTimer;
    CLLocationManager *_locationManager;
    NSString *_currentCity;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _currentCity = nil;
    
    NSError *error;
    if (![[self fetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);  // Fail
    }
    if (!_locationManager) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0 &&
//            [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse
            [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways
            ) {
            // Will open an confirm dialog to get user's approval
//            [_locationManager requestWhenInUseAuthorization];
            [_locationManager requestAlwaysAuthorization];
        }
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = [[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
    return numberOfRows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger numberOfSections = [[self.fetchedResultsController sections] count];
    return numberOfSections;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kNoteCellIdentifier];
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section
{
    return 0;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return YES if you want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self managedObjectContext];
        Note *note = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self updateObjectOnWeb:note withAction:kDelete];
        [context deleteObject:note];
        
        NSError *error = nil;
        // Save the object to persistent store
        if (![context save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
        
        
    }
}

- (NSData*)encodeDictionary:(NSDictionary*)dictionary {
    NSMutableArray *parts = [[NSMutableArray alloc] init];
    for (NSString *key in dictionary) {
        NSString *encodedValue = [[dictionary objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *part = [NSString stringWithFormat: @"%@=%@", encodedKey, encodedValue];
        [parts addObject:part];
    }
    NSString *encodedDictionary = [parts componentsJoinedByString:@"&"];
    return [encodedDictionary dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeObject:(Note *)anObject
      atIndexPath:(NSIndexPath *)indexPath
    forChangeType:(NSFetchedResultsChangeType)type
     newIndexPath:(NSIndexPath *)newIndexPath
{
    if (anObject.objectID.isTemporaryID) {
        return;
    }
    
    UITableView *tableView = self.tableView;
    [tableView reloadData];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Note *note = (Note *)[self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = note.note;
    cell.detailTextLabel.text = note.category;
    [cell layoutSubviews];
}

- (void)updateObjectOnWeb:(Note*)note withAction:(ActionType)actionType
{
    NSString *urlString = [NSString stringWithFormat:@"%@/n/%@/", [self mainURL], note.uuid];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSDictionary *postDict = nil;
    if (actionType == kDelete) {
        postDict = @{
                     @"action" : @"delete",
                     @"note_text" : note.note
                     };
    } else if(actionType == kUpdate) {
        postDict = @{
                     @"action" : @"update",
                     @"note_text" : note.note,
                     @"note_city" : _currentCity
                     };
    }

    NSData *postData = [self encodeDictionary:postDict];
    
    // Create the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)postData.length] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Peform the request
        NSURLResponse *response;
        NSError *error = nil;
        NSData *receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error) {
            // Deal with your error
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                NSLog(@"HTTP Error: %ld %@", (long)httpResponse.statusCode, error);
                return;
            }
            NSLog(@"Error %@", error);
            return;
        }
    });
}

- (IBAction)reloadNotes:(id)sender {
    
    NSString *urlString = [NSString stringWithFormat:@"%@/notes/all", [self mainURL]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // Create the request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Peform the request
        NSURLResponse *response;
        NSError *error = nil;
        NSData *receivedData = [NSURLConnection sendSynchronousRequest:request
                                                     returningResponse:&response
                                                                 error:&error];
        NSManagedObjectContext *context = [self managedObjectContext];
        
        NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:receivedData options:kNilOptions error:&error];
        
        if (error) {
            // Deal with your error
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                NSLog(@"HTTP Error: %ld %@", (long)httpResponse.statusCode, error);
                return;
            }
            NSLog(@"Error %@", error);
            return;
        }
        
        if ([jsonArray count] == 0) {
            NSLog(@"no changes");
            return;
        }
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity =
        [NSEntityDescription entityForName:[Note entityName]
                    inManagedObjectContext:context];
        [request setEntity:entity];
        
        [jsonArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSError *error = nil;
            Note *note = nil;
            NSString *uuid = [obj valueForKey:@"note_id"];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", uuid];
            [request setPredicate:predicate];
            
            NSArray *results = [context executeFetchRequest:request error:&error];
            if ([results count] > 0) {
                note = results[0];
            } else {
                note = [NSEntityDescription insertNewObjectForEntityForName:[Note entityName] inManagedObjectContext:context];
                note.uuid = uuid;
            }
            
            if (![[obj valueForKey:@"note_text"] isEqualToString:note.note]) {
                note.note = [obj valueForKey:@"note_text"];
            }
            
            NSString *category = [obj valueForKey:@"note_category"];
            if (![category isEqual:[NSNull null]]) {
                note.category = category;
            }
            
            NSString *date = [obj valueForKey:@"note_date"];
            NSTimeInterval seconds = [date doubleValue];
            NSDate *epochNSDate = [[NSDate alloc] initWithTimeIntervalSince1970:seconds];
            note.date = epochNSDate;
            
            NSString *answer = [obj valueForKey:@"note_answer"];
            if (![answer isEqual:[NSNull null]]) {
                note.answer = answer;
            }
        }];

        if (![context save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
    });
    
    
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ( [[segue identifier] isEqualToString:kNewNoteSegueIdentifier] ){
        PATextViewController *textViewController = (PATextViewController *)[segue destinationViewController];
        textViewController.delegate = self;
        
        NSManagedObjectContext *context = [self managedObjectContext];
        
        NSString *uuid = [[NSUUID UUID] UUIDString];
        // Create a new managed object
        Note *note = [NSEntityDescription insertNewObjectForEntityForName:[Note entityName] inManagedObjectContext:context];
        [note setValue:@"" forKey:@"note"];
        [note setValue:[NSDate date] forKey:@"date"];
        [note setValue:[NSDate date] forKey:@"updatedDate"];
        [note setValue:uuid forKey:@"uuid"];
        
        NSLog(@"%@", uuid);
        
        NSError *error = nil;
        // Save the object to persistent store
        if (![context save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
        
        textViewController.note = note;
    } else if ([[segue identifier] isEqualToString:kUpdateNoteSegueIdentifier]) {
        NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
        PATextViewController *textViewController = (PATextViewController *)[segue destinationViewController];
        textViewController.note = [self.fetchedResultsController objectAtIndexPath:indexPath];
        textViewController.delegate = self;
    }
}


- (void)textViewController:(PATextViewController *)viewController didEndEditing:(BOOL)didEnd withNote:(NSString *)noteText {
    Note *note = viewController.note;
    NSManagedObjectContext *context = [self managedObjectContext];
    
    if ([noteText isEqualToString:@""]) {
        [context deleteObject:note];
        [self updateObjectOnWeb:note withAction:kDelete];
    } else if (![noteText isEqualToString:note.note]) {
        note.note = noteText;
        [self updateObjectOnWeb:note withAction:kUpdate];
    }
    
    NSError *error = nil;
    // Save the object to persistent store
    if ([context hasChanges] && ![context save:&error]) {
        NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
    }
}

- (NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:[Note entityName] inManagedObjectContext:[self managedObjectContext]];
    [fetchRequest setEntity:entity];
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc]
                              initWithKey:@"date" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    [fetchRequest setFetchBatchSize:10000];
    
    NSFetchedResultsController *theFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[self managedObjectContext] sectionNameKeyPath:nil
                                                   cacheName:nil];
    
    self.fetchedResultsController = theFetchedResultsController;
    _fetchedResultsController.delegate = self;
    
    return _fetchedResultsController;
    
}

- (NSManagedObjectContext *)managedObjectContext {
    NSManagedObjectContext *context = nil;
    id delegate = [[UIApplication sharedApplication] delegate];
    if ([delegate performSelector:@selector(managedObjectContext)]) {
        context = [delegate managedObjectContext];
    }
    return context;
}


- (NSString *)mainURL
{
#if DEBUG
    return @"http://localhost:8000";
#endif
    return @"http://www.shareprepare.com";
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusNotDetermined: {
            NSLog(@"User still thinking..");
        } break;
        case kCLAuthorizationStatusDenied: {
            NSLog(@"User hates you");
        } break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways: {
            [_locationManager startUpdatingLocation]; //Will update location immediately
        } break;
        default:
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
    CLLocation *location = [locations lastObject];
    NSLog(@"lat%f - lon%f", location.coordinate.latitude, location.coordinate.longitude);
    
    if (!_currentCity) {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init] ;
        [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error)
         {
             if (!(error))
             {
                 CLPlacemark *placemark = [placemarks objectAtIndex:0];
                 NSLog(@"\nCurrent Location Detected\n");
                 //             NSLog(@"placemark %@",placemark);
                 NSString *locatedAt = [[placemark.addressDictionary valueForKey:@"FormattedAddressLines"] componentsJoinedByString:@", "];
                 NSString *Address = [[NSString alloc]initWithString:locatedAt];
                 NSString *Area = [[NSString alloc]initWithString:placemark.locality];
                 NSString *Country = [[NSString alloc]initWithString:placemark.country];
                 NSString *CountryArea = [NSString stringWithFormat:@"%@, %@", Area,Country];
                 _currentCity = Area;
             }
             else
             {
                 NSLog(@"Geocode failed with error %@", error);
                 NSLog(@"\nCurrent Location Not Detected\n");
                 //return;
                 NSString *CountryArea = NULL;
             }
             /*---- For more results
              placemark.region);
              placemark.country);
              placemark.locality);
              placemark.name);
              placemark.ocean);
              placemark.postalCode);
              placemark.subLocality);
              placemark.location);
              ------*/
         }];
    }
}

@end


