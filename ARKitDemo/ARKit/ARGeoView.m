//
//  ARGeoViewController.m
//  ARKitDemo
//
//  Created by Zac White on 8/2/09.
//  Copyright 2009 Zac White. All rights reserved.
//

#import "ARGeoView.h"

#import "ARGeoCoordinate.h"

@implementation ARGeoView

@synthesize centerLocation;

- (void)startListening
{
#if 1 || defined (DEBUG)
		// [Sunnyvale, CA] Yahoo!
		CLLocation *newCenter = [[CLLocation alloc] initWithLatitude:37.41711 longitude:-122.02528];
		self.centerLocation = newCenter;
		[newCenter release];
#endif
	
	[super startListening];
}

- (void)setCenterLocation:(CLLocation *)newLocation {
	[centerLocation release];
	centerLocation = [newLocation retain];
	
	for (ARGeoCoordinate *geoLocation in self.coordinates) {
		if ([geoLocation isKindOfClass:[ARGeoCoordinate class]]) {
			[geoLocation calibrateUsingOrigin:centerLocation];
			
			if ((((self.maximumDrawDistance > 0) && (geoLocation.radialDistance < self.maximumDrawDistance)) || (self.maximumDrawDistance < 0)) &&
				(geoLocation.radialDistance > self.maximumScaleDistance)) {
				self.maximumScaleDistance = geoLocation.radialDistance;
			}
		}
	}
}

@end
