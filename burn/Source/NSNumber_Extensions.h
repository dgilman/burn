//
//  NSNumber_Extensions.h
//  Burn
//
//  Created by Maarten Foukhar on 28-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSNumber (MyExtensions)
+ (NSNumber *)numberWithCGFloat:(CGFloat)value;
- (CGFloat)cgfloatValue;
@end
