//
//  Note.m
//  PowerNote
//
//  Created by paubins on 1/11/15.
//  Copyright (c) 2015 paubins. All rights reserved.
//

#import "Note.h"


@implementation Note

@dynamic note;
@dynamic date;
@dynamic uuid;
@dynamic category;
@dynamic updatedDate;
@dynamic answer;

+ (NSString *)entityName
{
    return NSStringFromClass(self);
}


@end
