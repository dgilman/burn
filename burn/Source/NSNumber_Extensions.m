//
//  NSNumber_Extensions.m
//  Burn
//
//  Created by Maarten Foukhar on 28-01-11.
//  Copyright 2011 Kiwi Fruitware. All rights reserved.
//

#import "NSNumber_Extensions.h"


@implementation NSNumber (MyExtensions)

+ (NSNumber *)numberWithCGFloat:(CGFloat)value
{
	#if __LP64__ || NS_BUILD_32_LIKE_64
	return [NSNumber numberWithDouble:value];
	#else
	return [NSNumber numberWithFloat:value];
	#endif
}

- (CGFloat)cgfloatValue
{
	#if __LP64__ || NS_BUILD_32_LIKE_64
	return [self doubleValue];
	#else
	return [self floatValue];
	#endif
}

@end
