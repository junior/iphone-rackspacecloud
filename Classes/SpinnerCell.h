//
//  SpinnerCell.h
//  Rackspace Cloud
//
//  Created by Michael Mayo on 12/12/08.
//  Copyright 2009 Rackspace Hosting. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SpinnerCell : UITableViewCell {
	UIActivityIndicatorView *spinner;
	UILabel *message;
}

@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@property (nonatomic, retain) UILabel *message;

@end
