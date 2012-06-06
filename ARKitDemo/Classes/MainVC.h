//
//  MainVC.h
//  ARKitDemo
//
//  Created by Серебряков Антон on 06.06.12.
//  Copyright (c) 2012 Zac White. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARGeoView.h"

@interface MainVC : UIViewController <ARViewDelegate>
{
	ARGeoView *geoView;
}

@end
