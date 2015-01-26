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

@implementation PATableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    
    // Fetch the devices from persistent data store
    NSError *error;
    if (![[self fetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);  // Fail
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kNoteCellIdentifier];
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
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
        [[self managedObjectContext] deleteObject:note];
        
        NSError *error = nil;
        // Save the object to persistent store
        if (![context save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
        
    }
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
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
    UITableView *tableView = self.tableView;
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            [tableView reloadRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
    
    if (!anObject.objectID.isTemporaryID && (type == NSFetchedResultsChangeUpdate || type == NSFetchedResultsChangeInsert)) {
        [self updatedObjectOnWeb:anObject];
    }
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Note *note = (Note *)[self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = note.note;
    cell.detailTextLabel.text = note.category;
    [cell layoutSubviews];
}

- (void)updatedObjectOnWeb:(Note*)note
{
    NSString *urlString = [NSString stringWithFormat:@"%@/n/", [self mainURL]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    double milliseconds = [note.date timeIntervalSinceReferenceDate]*1000;
    int myInt = (int)(milliseconds + (milliseconds>0 ? 0.5 : -0.5));
    NSString* myNewString = [NSString stringWithFormat:@"%d", myInt];

    NSDictionary *postDict = @{@"note_id" : note.uuid,
                               @"note_text" : note.note,
                               @"note_date" : myNewString
                               };
    
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
        NSData *receivedData = [NSURLConnection sendSynchronousRequest:request
                                                     returningResponse:&response
                                                                 error:&error];
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
    
    NSString *urlString = [NSString stringWithFormat:@"%@/notes/changes", [self mainURL]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSDictionary *postDict = [NSDictionary dictionaryWithObjectsAndKeys:@"1", @"get_updates", nil];
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
        NSData *receivedData = [NSURLConnection sendSynchronousRequest:request
                                                     returningResponse:&response
                                                                 error:&error];
        
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
        
        NSMutableArray *noteUUIDs = [NSMutableArray new];
        for (NSArray *change in jsonArray) {
            [noteUUIDs addObject:[change objectAtIndex:0]];
        }

        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity =
        [NSEntityDescription entityForName:[Note entityName]
                    inManagedObjectContext:[self managedObjectContext]];
        [request setEntity:entity];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid in %@", noteUUIDs];
        [request setPredicate:predicate];
        
        NSManagedObjectContext *context = [self managedObjectContext];
        NSArray *results = [context executeFetchRequest:request error:&error];
        if (results != nil) {
            if ([results count] != 0) {
                for(Note *note in results){
                    [jsonArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        NSString *currentNote = [obj valueForKey:@"note_id"];
                        if ([note.uuid isEqualToString:currentNote]) {
                            note.note = [obj valueForKey:@"note_text"];
                            
                            NSString *category = [obj valueForKey:@"note_category"];
                            if (![category isEqual:[NSNull null]]) {
                                note.category = category;
                            }
                            
                            NSString *date = [obj valueForKey:@"note_date"];
                            if (![date isEqual:[NSNull null]]) {
                                // Convert NSString to NSTimeInterval
                                NSTimeInterval seconds = [date doubleValue];
                                
                                NSDate *epochNSDate = [[NSDate alloc] initWithTimeIntervalSince1970:seconds];
                                note.date = epochNSDate;
                            }
                        }
                    }];
                }
            } else {
                [jsonArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    Note *note = [NSEntityDescription insertNewObjectForEntityForName:[Note entityName] inManagedObjectContext:context];
                    note.uuid = [obj valueForKey:@"note_id"];
                    note.note = [obj valueForKey:@"note_text"];
                    
                    NSString *category = [obj valueForKey:@"note_category"];
                    if (![category isEqual:[NSNull null]]) {
                        note.category = category;
                    }
                    
                    NSString *date = [obj valueForKey:@"note_date"];
                    if (![date isEqual:[NSNull null]]) {
                        // Convert NSString to NSTimeInterval
                        NSTimeInterval seconds = [date doubleValue];
                        
                        // (Step 1) Create NSDate object
                        NSDate *epochNSDate = [[NSDate alloc] initWithTimeIntervalSince1970:seconds];
                        note.date = epochNSDate;
                    } else {
                        note.date = [NSDate date];
                    }
                }];
            }

            NSError *error = nil;
            // Save the object to persistent store
            if (![context save:&error]) {
                NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
            }
            
            jsonArray = nil;
            results  = nil;
            request = nil;
            noteUUIDs = nil;
        }
        else {
            // Deal with error.
        }
    });

}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ( [[segue identifier] isEqualToString:kNewNoteSegueIdentifier] ){
        PATextViewController *textViewController = (PATextViewController *)[segue destinationViewController];
        
        NSManagedObjectContext *context = [self managedObjectContext];
        
        NSString *uuid = [[NSUUID UUID] UUIDString];
        // Create a new managed object
        Note *note = [NSEntityDescription insertNewObjectForEntityForName:[Note entityName] inManagedObjectContext:context];
        [note setValue:@"" forKey:@"note"];
        [note setValue:[NSDate date] forKey:@"date"];
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
    [fetchRequest setFetchBatchSize:20];
    
    NSFetchedResultsController *theFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[self managedObjectContext] sectionNameKeyPath:nil
                                                   cacheName:@"Root"];
    
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
    return @"http://localhost:8093";
#endif
    return @"http://www.shareprepare.com";
}



@end


