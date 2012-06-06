//
//  ARCoordinate.h
//  ARKitDemo
//
//  Created by Zac White on 8/1/09.
//  Copyright 2009 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MapKit/MapKit.h>

@class ARCoordinate;

@interface ARCoordinate : NSObject {
	CLLocationDistance radialDistance;
	CLLocationDegrees inclination;
	CLLocationDegrees azimuth;
	
	NSString *title;
	NSString *subtitle;
}

- (NSUInteger)hash;
- (BOOL)isEqual:(id)other;
- (BOOL)isEqualToCoordinate:(ARCoordinate *)otherCoordinate;

+ (ARCoordinate *)coordinateWithRadialDistance:(double)newRadialDistance inclination:(double)newInclination azimuth:(double)newAzimuth;

@property (nonatomic, retain) NSString *title;
@property (nonatomic, copy) NSString *subtitle;

@property (nonatomic) CLLocationDistance radialDistance;
@property (nonatomic) CLLocationDistance inclination;
@property (nonatomic) CLLocationDistance azimuth;

@end
