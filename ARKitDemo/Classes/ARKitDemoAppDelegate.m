//
//  ARKitDemoAppDelegate.m
//  ARKitDemo
//
//  Created by Zac White on 8/1/09.
//  Copyright Zac White 2009. All rights reserved.
//

#import "ARKitDemoAppDelegate.h"
#import "ARGeoCoordinate.h"

#import <MapKit/MapKit.h>

@implementation ARKitDemoAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(UIApplication *)application {    
	
	ARGeoViewController *viewController = [[ARGeoViewController alloc] init];
	viewController.debugMode = YES;
	viewController.delegate = self;
	viewController.scaleViewsBasedOnDistance = YES;
	viewController.minimumScaleFactor = .5;
	viewController.rotateViewsBasedOnPerspective = YES;
	viewController.maximumDrawDistance = -1;
	
	NSMutableArray *tempLocationArray = [[NSMutableArray alloc] initWithCapacity:10];
	
	CLLocation *tempLocation = nil;
	ARGeoCoordinate *tempCoordinate = nil;
	
	{
		CLLocationCoordinate2D location;
		location.latitude = 39.550051;
		location.longitude = -105.782067;
		
		tempLocation = [[CLLocation alloc] initWithCoordinate:location altitude:1609.0 horizontalAccuracy:1.0 verticalAccuracy:1.0 timestamp:[NSDate date]];
		
		tempCoordinate = [ARGeoCoordinate coordinateWithLocation:tempLocation];
		tempCoordinate.title = @"Denver";
		
		[tempLocationArray addObject:tempCoordinate];
		[tempLocation release]; tempLocation = nil;
	}
	
	typedef struct {
		CLLocationCoordinate2D coordinate; /* latitude, longitude */
		CLLocationDegrees inclination;
		NSString *title;
	} NamedCoordinate;
	
	static const NamedCoordinate TheCoords[] = {
		/*{ latitude, longitude }, @"[Place] Title" */
		{{  48.649271,   44.430652 },       0, @"[ФизФак] Школа" },
		{{  48.650827,   44.431661 },       0, @"[ФизФак] Девятиэтажка" },
		{{  48.650407,   44.433066 },       0, @"[ФизФак] Общага" },
		{{  48.647838,   44.421405 },       0, @"[ФизФак] Янтарный город" },
		{{  48.647571,   44.431296 },       0, @"[ФизФак] Другая девятиэтажка" },
		{{  48.697346,   44.494919 },       0, @"[Офис] (70м) Дом через дорогу по диагонали" },
		{{  48.698103,   44.493996 },       0, @"[Офис] (90м) “Волгоградэнергооблгаз”, в сторону ж/д" },
		{{  48.697579,   44.492226 },       0, @"[Офис] (130м) Ближайшая школа, к северо-западу" },
		{{  48.689633,   44.492977 },       0, @"[Офис] Столовая №1" },
		{{  45.523875, -122.670399 },       0, @"Portland" },
		{{  41.879535,  -87.624333 },       0, @"Chicago" },
		{{  30.268735,  -97.745209 },       0, @"Austin" },
		{{  51.500152,   -0.126236 }, M_PI/30, @"London" },
		{{  51.500152,   -0.126236 }, M_PI/30, @"Paris" },
		{{  47.620973, -122.347276 },       0, @"Seattle" },
		{{  20.593684,   78.962880 }, M_PI/32, @"India" },
		{{  55.676294,   12.568116 }, M_PI/30, @"Copenhagen" },
		{{  52.373801,    4.890935 }, M_PI/30, @"Amsterdam" },
		{{  19.611544, -155.665283 }, M_PI/30, @"Hawaii" },
		{{ -40.900557,  174.885971 }, M_PI/40, @"New Zealand" },
		{{  40.756054,  -73.986951 },       0, @"New York City" },
		{{  42.358920,  -71.057810 },       0, @"Boston" },
		{{  49.817492,   15.472962 }, M_PI/30, @"Czech Republic" },
		{{  53.412910,   -8.243890 }, M_PI/30, @"Ireland" },
		{{  45.545447,  -73.639076 },       0, @"Montreal" },
		{{  38.892091,  -77.024055 },       0, @"Washington, DC" },
		{{ -40.900557,  174.885971 },       0, @"Munich" },
		{{  32.781078,  -96.797111 },       0, @"Dallas" },
		{{ 0, 0 }, 0, nil } // The end of array
	};
	
	for (const NamedCoordinate *item = &TheCoords[0]; item->title != nil; item++)
	{
		tempLocation = [[CLLocation alloc] initWithLatitude:item->coordinate.latitude longitude:item->coordinate.longitude];
		
		tempCoordinate = [ARGeoCoordinate coordinateWithLocation:tempLocation];
		tempCoordinate.inclination = item->inclination;
		tempCoordinate.title = item->title;
		
		[tempLocationArray addObject:tempCoordinate];
		[tempLocation release]; tempLocation = nil;
		
		NSLog(@"Coord (%f; %f) [%@] added!", item->coordinate.latitude, item->coordinate.longitude, item->title);
	}
	
	[viewController addCoordinates:tempLocationArray];
	[tempLocationArray release];

	[viewController startListening];
	
	[window addSubview:viewController.view];
	
    // Override point for customization after application launch
    [window makeKeyAndVisible];
}

#define BOX_WIDTH 150
#define BOX_HEIGHT 100

- (UIView *)viewForCoordinate:(ARCoordinate *)coordinate {
	
	CGRect theFrame = CGRectMake(0, 0, BOX_WIDTH, BOX_HEIGHT);
	UIView *tempView = [[UIView alloc] initWithFrame:theFrame];
	
	//tempView.backgroundColor = [UIColor colorWithWhite:.5 alpha:.3];
	
	UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, BOX_WIDTH, 20.0)];
	titleLabel.backgroundColor = [UIColor colorWithWhite:.3 alpha:.8];
	titleLabel.textColor = [UIColor whiteColor];
	titleLabel.textAlignment = UITextAlignmentCenter;
	titleLabel.text = coordinate.title;
	[titleLabel sizeToFit];
	
	titleLabel.frame = CGRectMake(BOX_WIDTH / 2.0 - titleLabel.frame.size.width / 2.0 - 4.0, 0, titleLabel.frame.size.width + 8.0, titleLabel.frame.size.height + 8.0);
	
	UIImageView *pointView = [[UIImageView alloc] initWithFrame:CGRectZero];
	pointView.image = [UIImage imageNamed:@"location.png"];
	pointView.frame = CGRectMake((int)(BOX_WIDTH / 2.0 - pointView.image.size.width / 2.0), (int)(BOX_HEIGHT / 2.0 - pointView.image.size.height / 2.0), pointView.image.size.width, pointView.image.size.height);

	[tempView addSubview:titleLabel];
	[tempView addSubview:pointView];
	
	[titleLabel release];
	[pointView release];
	
	return [tempView autorelease];
}


- (void)dealloc {
	
	//NEW COMMENT!
    [window release];
    [super dealloc];
}


@end
