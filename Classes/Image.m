//
//  Image.m
//  Rackspace
//
//  Created by Michael Mayo on 6/7/09.
//  Copyright 2009 Rackspace Hosting. All rights reserved.
//

#import "Image.h"
#import "ObjectiveResource.h"
#import "RackspaceAppDelegate.h"
#import "Response.h"
#import "ORConnection.h"
#import "Server.h"

@implementation Image

@synthesize imageId, imageName, timeStamp, status, progress, serverId;

- (NSString *)imageName {
	NSString *name = imageName;
	if (self.serverId) {
		RackspaceAppDelegate *app = (RackspaceAppDelegate *) [[UIApplication sharedApplication] delegate];	
		Server *aServer = (Server *) [app.servers objectForKey:self.serverId];	
		if (aServer) {
			name = [NSString stringWithFormat:@"%@ (%@)", imageName, aServer.serverName];
		}
	} 
	return name;
}

// Find all items 
+ (NSArray *)findAllRemoteWithResponse:(NSError **)aError {
	
	RackspaceAppDelegate *app = (RackspaceAppDelegate *) [[UIApplication sharedApplication] delegate];	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@images/detail.xml", app.computeUrl]];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
	Response *res = [ORConnection sendRequest:request withAuthToken:app.authToken];	
	if([res isError] && aError) {
		*aError = res.error;
	}
	
	return [self performSelector:@selector(fromXMLData:) withObject:res.body];
}

+ (Image *)findLocalWithImageId:(NSString *)imageId {
	RackspaceAppDelegate *app = (RackspaceAppDelegate *) [[UIApplication sharedApplication] delegate];
	Image *image = nil;
	for (int i = 0; i < [app.images count]; i++) {
		Image *tempImage = (Image *) [app.images objectAtIndex:i];
		if ([tempImage.imageId isEqualToString:imageId]) {
			image = tempImage;
			break;
		}
	}
	return image;
}

// don't fully trust this method, as a backup image could be windows but return NO
// because it's not one of the Rackspace-provided Windows images
- (BOOL) isWindows {	
	return [self.imageId isEqualToString:@"23"] || [self.imageId isEqualToString:@"24"]
			|| [self.imageId isEqualToString:@"28"] || [self.imageId isEqualToString:@"29"]
			|| [self.imageId isEqualToString:@"31"];
}

- (void) dealloc {
	[imageId release];
	[imageName release];
	[timeStamp release];
	[status release];
	[progress release];
	[serverId release];
	[super dealloc];
}

@end
