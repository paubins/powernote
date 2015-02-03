//
//  Note.h
//  PowerNote
//
//  Created by paubins on 1/11/15.
//  Copyright (c) 2015 paubins. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Note : NSManagedObject

@property (nonatomic, retain) NSString * note;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSString * category;
@property (nonatomic, retain) NSDate * updatedDate;
@property (nonatomic, retain) NSString * answer;


+ (NSString *)entityName;

@end
