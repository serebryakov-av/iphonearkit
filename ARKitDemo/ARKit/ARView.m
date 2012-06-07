//
//  ARKViewController.m
//  ARKitDemo
//
//  Created by Zac White on 8/1/09.
//  Copyright 2009 Zac White. All rights reserved.
//

#import "ARView.h"

#import <QuartzCore/QuartzCore.h>

#define VIEWPORT_WIDTH_RADIANS (.5 + .1)
#define VIEWPORT_HEIGHT_RADIANS (.7392 + .2)

@implementation ARView

@synthesize locationManager, accelerometerManager;
@synthesize centerCoordinate;

@synthesize scaleViewsBasedOnDistance, rotateViewsBasedOnPerspective;
@synthesize maximumScaleDistance;
@synthesize minimumScaleFactor, maximumRotationAngle;
@synthesize maximumDrawDistance;

@synthesize updateFrequency;

@synthesize debugMode = ar_debugMode;

@synthesize coordinates = ar_coordinates;

@synthesize delegate, locationDelegate, accelerometerDelegate;

// Is augmented reality avaible on current device
+ (BOOL)isAvaible
{
	return [CLLocationManager headingAvailable] &&
    [CLLocationManager locationServicesEnabled] &&
    [UIAccelerometer sharedAccelerometer];
}

- (id)init
{
	if (!(self = [super init])) return nil;
	
	ar_debugView = nil;
	ar_debugMode = NO;
	
	ar_coordinates = [NSMutableArray new];
	ar_coordinateViews = [NSMutableArray new];
	
	_updateTimer = nil;
	self.updateFrequency = 1 / 20.0;
	
	self.scaleViewsBasedOnDistance = NO;
	self.maximumScaleDistance = 0.0;
	self.minimumScaleFactor = 1.0;
	
	self.maximumDrawDistance = -1; // In meters (Don't used if <= 0)
	
	self.rotateViewsBasedOnPerspective = NO;
	self.maximumRotationAngle = M_PI / 6.0;
	
	if (!ar_videoImageView)
	{
		ar_videoImageView = [[[UIImageView alloc] initWithFrame:self.bounds] autorelease];
		ar_videoImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self insertSubview:ar_videoImageView atIndex:0];
	}
	
	return self;
}

- (id)initWithLocationManager:(CLLocationManager *)manager
{
	if (!(self = [super init])) return nil;
	
	//use the passed in location manager instead of ours.
	self.locationManager = manager;
	self.locationManager.delegate = self;
	
	self.locationDelegate = nil;
	
	return self;
}

- (void)activateVideo
{
#if !TARGET_IPHONE_SIMULATOR
	
	if (!captureDeviceInput)
	{
		AVCaptureDevice *vid_dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		if ([vid_dev supportsAVCaptureSessionPreset:AVCaptureSessionPresetMedium])
			captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:vid_dev error:nil];
	}
	
	if (captureDeviceInput && !captureVideoDataOutput)
	{
		/*We setupt the output*/
		captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
		/*While a frame is processes in
		 -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
		 If you don't want this behaviour set the property to NO */
		captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES; 
		/*We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
		 in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
		 In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
		 we are not able to process more than 10 frames per second.*/
		//captureVideoDataOutput.minFrameDuration = CMTimeMake(1, 20);
		/*We create a serial queue to handle the processing of our frames*/
		dispatch_queue_t queue = dispatch_queue_create("cameraQueue", NULL);
		[captureVideoDataOutput setSampleBufferDelegate:self queue:queue];
		dispatch_release(queue);
		// Set the video output to store frame in BGRA (It is supposed to be faster)
		NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey; 
		NSNumber *value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
		NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
		[captureVideoDataOutput setVideoSettings:videoSettings];
	}
	
	if (captureDeviceInput && captureVideoDataOutput && !captureSession)
	{
		/*And we create a capture session*/
		captureSession = [[AVCaptureSession alloc] init];
		captureSession.sessionPreset = AVCaptureSessionPresetMedium;
		/*We add input and output*/
		[captureSession addInput:captureDeviceInput];
		[captureSession addOutput:captureVideoDataOutput];
	}
	
#endif
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{ @autoreleasepool {
	
	CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	/*Lock the image buffer*/
	CVPixelBufferLockBaseAddress(imageBuffer, 0);
	/*Get information about the image*/
	uint *imageData = (uint *)CVPixelBufferGetBaseAddress(imageBuffer); 
	//int bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
	int width = CVPixelBufferGetWidth(imageBuffer); 
	int height = CVPixelBufferGetHeight(imageBuffer);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width*4, colorSpace, kCGBitmapByteOrder32Little|kCGImageAlphaPremultipliedFirst);
	CGImageRef imgRef = CGBitmapContextCreateImage(context);
	UIImage *image = [UIImage imageWithCGImage:imgRef scale:1.0 orientation:UIImageOrientationRight];
	dispatch_async(dispatch_get_main_queue(), ^{
		ar_videoImageView.contentMode = UIViewContentModeCenter;
		ar_videoImageView.contentScaleFactor = 1.0f;
		ar_videoImageView.image = image;
	});
	CGImageRelease(imgRef);
	CGContextRelease(context); 
	CGColorSpaceRelease(colorSpace);
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}}

- (void)setUpdateFrequency:(double)newUpdateFrequency
{
	updateFrequency = newUpdateFrequency;
	
	if (!_updateTimer) return;
	
	[_updateTimer invalidate];
	[_updateTimer release];
	
	_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:self.updateFrequency
													 target:self
												   selector:@selector(updateLocations:)
												   userInfo:nil
													repeats:YES] retain];
}

- (void)setMaximumDrawDistance:(CLLocationDistance)newMaximumDrawDistance
{
	maximumDrawDistance = newMaximumDrawDistance;
	
	self.maximumScaleDistance = 0;
	
	for (ARCoordinate *coordinate in ar_coordinates)
	{
		if ((((self.maximumDrawDistance > 0) && (coordinate.radialDistance < self.maximumDrawDistance)) || (self.maximumDrawDistance < 0)) &&
			(coordinate.radialDistance > self.maximumScaleDistance))
			self.maximumScaleDistance = coordinate.radialDistance;
	}
}

- (void)setDebugMode:(BOOL)flag
{
	if (self.debugMode == flag) return;
	
	ar_debugMode = flag;
	
	if (self.debugMode)
	{
		if (!ar_debugView)
		{
			ar_debugView = [[UILabel alloc] initWithFrame:CGRectZero];
			ar_debugView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
			ar_debugView.textAlignment = UITextAlignmentCenter;
			ar_debugView.text = @"Waiting...";
			
			[ar_debugView sizeToFit];
			ar_debugView.frame = CGRectMake(0, ar_videoImageView.frame.size.height - ar_debugView.frame.size.height, ar_videoImageView.frame.size.width, ar_debugView.frame.size.height);
			
			[ar_videoImageView addSubview:ar_debugView];
		}
	}
	else
	{
		[ar_debugView removeFromSuperview];
		[ar_debugView release];
		ar_debugView = nil;
	}
}

- (BOOL)viewportContainsCoordinate:(ARCoordinate *)coordinate
{
	if (self.maximumDrawDistance > 0 &&
		coordinate.radialDistance > self.maximumDrawDistance)
		return NO;
	
	double centerAzimuth = self.centerCoordinate.azimuth;
	double leftAzimuth = centerAzimuth - VIEWPORT_WIDTH_RADIANS / 2.0;
	
	if (leftAzimuth < 0.0) {
		leftAzimuth = 2 * M_PI + leftAzimuth;
	}
	
	double rightAzimuth = centerAzimuth + VIEWPORT_WIDTH_RADIANS / 2.0;
	
	if (rightAzimuth > 2 * M_PI) {
		rightAzimuth = rightAzimuth - 2 * M_PI;
	}
	
	BOOL result = (coordinate.azimuth > leftAzimuth && coordinate.azimuth < rightAzimuth);
	
	if(leftAzimuth > rightAzimuth) {
		result = (coordinate.azimuth < rightAzimuth || coordinate.azimuth > leftAzimuth);
	}
	
	double centerInclination = self.centerCoordinate.inclination;
	double bottomInclination = centerInclination - VIEWPORT_HEIGHT_RADIANS / 2.0;
	double topInclination = centerInclination + VIEWPORT_HEIGHT_RADIANS / 2.0;
	
	//check the height.
	result = result && (coordinate.inclination > bottomInclination && coordinate.inclination < topInclination);
	
	//NSLog(@"coordinate: %@ result: %@", coordinate, result?@"YES":@"NO");
	
	return result;
}

- (void)startListening
{
	//start our heading readings and our accelerometer readings.
	
	if (!self.locationManager)
	{
		self.locationManager = [[[CLLocationManager alloc] init] autorelease];
		
		//we want every move.
		self.locationManager.headingFilter = kCLHeadingFilterNone;
		self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
	}
	
	if (self.locationManager)
	{
		[self.locationManager startUpdatingHeading];
		[self.locationManager startUpdatingLocation];
		
		//steal back the delegate.
		self.locationManager.delegate = self;
	}
	
	if (!self.accelerometerManager)
	{
		self.accelerometerManager = [UIAccelerometer sharedAccelerometer];
		self.accelerometerManager.updateInterval = 0.01;
		self.accelerometerManager.delegate = self;
	}
	
	if (!self.centerCoordinate)
	{
		self.centerCoordinate = [ARCoordinate coordinateWithRadialDistance:0 inclination:0 azimuth:0];
	}
	
#if !TARGET_IPHONE_SIMULATOR
	
	if (!captureSession)
		[self activateVideo];
	
	if (!captureSession.running)
		[captureSession startRunning];
	
#endif
	
	if (!_updateTimer)
	{
		_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:self.updateFrequency target:self selector:@selector(updateLocations:) userInfo:nil repeats:YES] retain];
	}
}

- (void)stopListening
{
	if (self.locationManager)
	{
		[self.locationManager stopUpdatingHeading];
		[self.locationManager stopUpdatingLocation];
	}
	
	if (self.accelerometerManager)
	{
		self.accelerometerManager.delegate = nil;
		self.accelerometerManager = nil;
	}
	
#if !TARGET_IPHONE_SIMULATOR
	
	if (captureSession.running)
		[captureSession stopRunning];
	
#endif
	
	[_updateTimer invalidate];
	[_updateTimer release];
	_updateTimer = nil;
}

- (CGPoint)pointInView:(UIView *)realityView forCoordinate:(ARCoordinate *)coordinate
{
	CGPoint point;
	
	//x coordinate.
	
	double pointAzimuth = coordinate.azimuth;
	
	//our x numbers are left based.
	double leftAzimuth = self.centerCoordinate.azimuth - VIEWPORT_WIDTH_RADIANS / 2.0;
	
	if (leftAzimuth < 0.0) {
		leftAzimuth = 2 * M_PI + leftAzimuth;
	}
	
	if (pointAzimuth < leftAzimuth)
	{
		//it's past the 0 point.
		point.x = ((2 * M_PI - leftAzimuth + pointAzimuth) / VIEWPORT_WIDTH_RADIANS) * realityView.frame.size.width;
	}
	else
	{
		point.x = ((pointAzimuth - leftAzimuth) / VIEWPORT_WIDTH_RADIANS) * realityView.frame.size.width;
	}
	
	//y coordinate.
	
	double pointInclination = coordinate.inclination;
	
	double topInclination = self.centerCoordinate.inclination - VIEWPORT_HEIGHT_RADIANS / 2.0;
	
	point.y = realityView.frame.size.height - ((pointInclination - topInclination) / VIEWPORT_HEIGHT_RADIANS) * realityView.frame.size.height;
	
	return point;
}

#define kFilteringFactor 0.05
UIAccelerationValue rollingX, rollingZ;

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
	// -1 face down.
	// 1 face up.
	
	//update the center coordinate.
	
	//NSLog(@"x: %f y: %f z: %f", acceleration.x, acceleration.y, acceleration.z);
	
	//this should be different based on orientation.
	
	rollingZ  = (acceleration.z * kFilteringFactor) + (rollingZ  * (1.0 - kFilteringFactor));
    rollingX = (acceleration.y * kFilteringFactor) + (rollingX * (1.0 - kFilteringFactor));
	
	if (rollingZ > 0.0) {
		self.centerCoordinate.inclination = atan(rollingX / rollingZ) + M_PI / 2.0;
	} else if (rollingZ < 0.0) {
		self.centerCoordinate.inclination = atan(rollingX / rollingZ) - M_PI / 2.0;// + M_PI;
	} else if (rollingX < 0) {
		self.centerCoordinate.inclination = M_PI/2.0;
	} else if (rollingX >= 0) {
		self.centerCoordinate.inclination = 3 * M_PI/2.0;
	}
	
	if (self.accelerometerDelegate && [self.accelerometerDelegate respondsToSelector:@selector(accelerometer:didAccelerate:)])
	{
		//forward the acceleromter.
		[self.accelerometerDelegate accelerometer:accelerometer didAccelerate:acceleration];
	}
}

/*NSComparisonResult LocationSortClosestFirst(ARCoordinate *s1, ARCoordinate *s2, void *ignore)
 {
 if (s1.radialDistance < s2.radialDistance) {
 return NSOrderedAscending;
 } else if (s1.radialDistance > s2.radialDistance) {
 return NSOrderedDescending;
 } else {
 return NSOrderedSame;
 }
 }*/

- (void)addCoordinate:(ARCoordinate *)coordinate
{
	[self addCoordinate:coordinate animated:YES];
}

- (void)addCoordinate:(ARCoordinate *)coordinate animated:(BOOL)animated
{
	//do some kind of animation?
	[ar_coordinates addObject:coordinate];
	
	if ((((self.maximumDrawDistance > 0) && (coordinate.radialDistance < self.maximumDrawDistance)) || (self.maximumDrawDistance < 0)) &&
		(coordinate.radialDistance > self.maximumScaleDistance))
	{
		self.maximumScaleDistance = coordinate.radialDistance;
	}
	
	//message the delegate.
	[ar_coordinateViews addObject:[self.delegate viewForCoordinate:coordinate]];
}

- (void)addCoordinates:(NSArray *)newCoordinates
{
	//go through and add each coordinate.
	for (ARCoordinate *coordinate in newCoordinates)
		[self addCoordinate:coordinate animated:NO];
}

- (void)removeCoordinate:(ARCoordinate *)coordinate
{
	[self removeCoordinate:coordinate animated:YES];
}

- (void)removeCoordinate:(ARCoordinate *)coordinate animated:(BOOL)animated
{
	//do some kind of animation?
	[ar_coordinates removeObject:coordinate];
}

- (void)removeCoordinates:(NSArray *)coordinates
{	
	for (ARCoordinate *coordinateToRemove in coordinates)
	{
		NSUInteger indexToRemove = [ar_coordinates indexOfObject:coordinateToRemove];
		
		//TODO: Error checking in here.
		
		[ar_coordinates removeObjectAtIndex:indexToRemove];
		[ar_coordinateViews removeObjectAtIndex:indexToRemove];
	}
}

- (void)updateLocations:(NSTimer *)timer
{
	//update locations!
	
	if (!ar_coordinateViews || ar_coordinateViews.count == 0) {
		return;
	}
	
	ar_debugView.text = [self.centerCoordinate description];
	
	int index = 0;
	for (ARCoordinate *item in ar_coordinates)
	{
		UIView *viewToDraw = [ar_coordinateViews objectAtIndex:index];
		
		if ([self viewportContainsCoordinate:item])
		{
			CGPoint loc = [self pointInView:ar_videoImageView forCoordinate:item];
			
			CGFloat scaleFactor = 1.0;
			if (self.scaleViewsBasedOnDistance)
			{
				scaleFactor = 1.0 - self.minimumScaleFactor * (item.radialDistance / self.maximumScaleDistance);
			}
			
			float width = viewToDraw.bounds.size.width * scaleFactor;
			float height = viewToDraw.bounds.size.height * scaleFactor;
			
			viewToDraw.frame = CGRectMake(loc.x - width / 2.0, loc.y - height / 2.0, width, height);
			
			CATransform3D transform = CATransform3DIdentity;
			
			//set the scale if it needs it.
			if (self.scaleViewsBasedOnDistance)
			{
				//scale the perspective transform if we have one.
				transform = CATransform3DScale(transform, scaleFactor, scaleFactor, scaleFactor);
			}
			
			if (self.rotateViewsBasedOnPerspective)
			{
				transform.m34 = 1.0 / 300.0;
				
				double itemAzimuth = item.azimuth;
				double centerAzimuth = self.centerCoordinate.azimuth;
				if (itemAzimuth - centerAzimuth > M_PI) centerAzimuth += 2*M_PI;
				if (itemAzimuth - centerAzimuth < -M_PI) itemAzimuth += 2*M_PI;
				
				double angleDifference = itemAzimuth - centerAzimuth;
				transform = CATransform3DRotate(transform, self.maximumRotationAngle * angleDifference / (VIEWPORT_HEIGHT_RADIANS / 2.0) , 0, 1, 0);
			}
			
			viewToDraw.layer.transform = transform;
			
			//if we don't have a superview, set it up.
			if (!(viewToDraw.superview))
			{
				[ar_videoImageView addSubview:viewToDraw];
				[ar_videoImageView sendSubviewToBack:viewToDraw];
			}
			
		}
		else
		{
			[viewToDraw removeFromSuperview];
			viewToDraw.transform = CGAffineTransformIdentity;
		}
		index++;
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
	self.centerCoordinate.azimuth = fmod(newHeading.trueHeading, 360.0) * (2 * (M_PI / 360.0));
	
	if (self.locationDelegate && [self.locationDelegate respondsToSelector:@selector(locationManager:didUpdateHeading:)])
	{
		//forward the call.
		[self.locationDelegate locationManager:manager didUpdateHeading:newHeading];
	}
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager
{
	if (self.locationDelegate && [self.locationDelegate respondsToSelector:@selector(locationManagerShouldDisplayHeadingCalibration:)])
	{
		//forward the call.
		return [self.locationDelegate locationManagerShouldDisplayHeadingCalibration:manager];
	}
	
	return YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
	if (self.locationDelegate && [self.locationDelegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)])
	{
		//forward the call.
		[self.locationDelegate locationManager:manager didUpdateToLocation:newLocation fromLocation:oldLocation];
	}
	else if ([self respondsToSelector:@selector(setCenterLocation:)])
	{
		NSLog(@"CurrentLocation: %@", newLocation);
		[self performSelector:@selector(setCenterLocation:) withObject:newLocation];
	}
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	if (self.locationDelegate && [self.locationDelegate respondsToSelector:@selector(locationManager:didFailWithError:)])
	{
		//forward the call.
		return [self.locationDelegate locationManager:manager didFailWithError:error];
	}
}

- (void)dealloc
{
	self.accelerometerManager.delegate = nil;
	self.accelerometerManager = nil;
	self.locationManager.delegate = nil;
	self.locationManager = nil;
	
	self.accelerometerDelegate = nil;
	self.locationDelegate = nil;
	self.delegate = nil;
	
	self.centerCoordinate = nil;
	
	[ar_debugView release];
	
	[ar_coordinateViews release];
	[ar_coordinates release];
	
    [super dealloc];
}

@end
