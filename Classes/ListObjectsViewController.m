//
//  ListObjectsViewController.m
//  Rackspace
//
//  Created by Michael Mayo on 6/21/09.
//  Copyright 2009 Michael Mayo. All rights reserved.
//

#import "ListObjectsViewController.h"
#import "Container.h"
#import "CloudFilesObject.h"
#import "GroupSpinnerCell.h"
#import "RackspaceAppDelegate.h"
#import "CFAccount.h"
#import "AddObjectViewController.h"
#import "ObjectViewController.h"
#import "RoundedRectView.h"
#import "Response.h"
#import "TextFieldCell.h"
#import "ListFolderObjectsViewController.h"
#import "ContainersRootViewController.h"


#define kContainerDetails 0
#define kCDN 1
#define kFolders 2
#define kFiles 3

@implementation ListObjectsViewController

@synthesize account, container, containerName, cdnSwitch, logSwitch, spinnerView, objectsContainer, ttlCell, containersRootViewController;

BOOL objectsLoaded = NO;
NSMutableArray *folderedObjects = nil;
NSMutableArray *unfolderedObjects = nil;
NSDictionary *folders = nil;


// thread to load containers
- (void) loadObjects {
	NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];
	if (!objectsLoaded) {
		RackspaceAppDelegate *app = (RackspaceAppDelegate *) [[UIApplication sharedApplication] delegate];
		[ObjectiveResourceConfig setSite:app.storageUrl];	
		[ObjectiveResourceConfig setAuthToken:app.authToken];
		[ObjectiveResourceConfig setResponseType:XmlResponse];	
		
		// the objectsContainer is a temporary holder for the files list
		self.objectsContainer = [Container findRemote:self.containerName withResponse:nil];
		self.container.objects = self.objectsContainer.objects;
		
		folderedObjects = [[NSMutableArray alloc] init];
		unfolderedObjects = [[NSMutableArray alloc] init];
		
		for (int i = 0; i < [self.container.objects count]; i++) {
			CloudFilesObject *cfo = [self.container.objects objectAtIndex:i];
			NSRange range = [cfo.name rangeOfString:@"/"];
			if (range.location == NSNotFound) {
				[unfolderedObjects addObject:cfo];
			} else {
				[folderedObjects addObject:cfo];
			}
		}
		
		NSLog(@"Foldered count: %i", [folderedObjects count]);
		NSLog(@"Unfoldered count: %i", [unfolderedObjects count]);
		
		// put folders files in folder
		folders = [[NSMutableDictionary alloc] init];
		for (int i = 0; i < [folderedObjects count]; i++) {
			CloudFilesObject *cfo = [folderedObjects objectAtIndex:i];
			NSString *key = [cfo.name substringToIndex:[cfo.name rangeOfString:@"/"].location];
			NSMutableArray *folder = [folders objectForKey:key];
			if (folder == nil) {
				folder = [[NSMutableArray alloc] init];
			}
			[folder addObject:cfo];
			[folders setValue:folder forKey:key];
		}
		
		objectsLoaded = YES;
		self.tableView.userInteractionEnabled = YES;
		[self.tableView reloadData];		
	}
	[autoreleasepool release];
}

- (void)showSaveError:(Response *)response {
	UIAlertView *alert;
	if (response.statusCode == 413) {
		alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Saving", @"Error Saving container alert title") 
										   message:NSLocalizedString(@"This container was not saved because you have exceeded the API rate limit.  Please contact the Rackspace Cloud to increase your limit or try again later.", @"Error saving container due to API rate limit alert message")
										  delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles: nil];
	} else {
		alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Saving", @"Error Saving container alert title") 
										   message:NSLocalizedString(@"This container was not saved.  Please check your connection or data and try again.", @"Error saving container due to connection or other error alert message")
										  delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles: nil];
	}
	[alert show];
	[alert release];	
}

- (void)cdnSwitchAction:(id)sender {
	NSLog(@"switchAction: value = %d", [sender isOn]);
	
	[self showSpinnerView];

	if ([sender isOn]) {
		self.container.cdnEnabled = @"True";
	} else {
		self.container.cdnEnabled = @"False";
	}
	Response *response = [self.container updateCdnAttributes:self.containersRootViewController.cdnAccount.containers];
	[self hideSpinnerView];
	
	NSLog(@"switch status code = %i", response.statusCode);
	// 202 - fine, but it was already CDN enabled
	// 201 - it was cdn enabled
	
	if (![response isSuccess]) {
		[self showSaveError:response];
	} else {
		// refresh the container object against the CDN Management URL so we'll be sure to have
		// the right CDN URI to use for file previews, etc
		[self.container refreshCDNAttributes];
		
		// refresh the containers list so we'll be sure to use the right http method
		// for CDN controls in the future
		[self.containersRootViewController refreshContainerList];
	}
}

- (UISwitch *)cdnSwitch {
    if (cdnSwitch == nil) {
        CGRect frame = CGRectMake(198.0, 9.0, 94.0, 27.0);
        cdnSwitch = [[UISwitch alloc] initWithFrame:frame];

        [cdnSwitch addTarget:self action:@selector(cdnSwitchAction:) forControlEvents:UIControlEventValueChanged];
        
        // in case the parent view draws with a custom color or gradient, use a transparent color
        cdnSwitch.backgroundColor = [UIColor clearColor];
		
		cdnSwitch.tag = 1;	// tag this view for later so we can remove it from recycled table cells
    }
    return cdnSwitch;
}

- (void)logSwitchAction:(id)sender {
	NSLog(@"switchAction: value = %d", [sender isOn]);

	[self showSpinnerView];

	if ([sender isOn]) {
		self.container.logRetention = @"True";
	} else {
		self.container.logRetention = @"False";
	}
	Response *response = [self.container save];
	[self hideSpinnerView];
	if (![response isSuccess]) {
		[self showSaveError:response];
	}
}

- (UISwitch *)logSwitch {
    if (logSwitch == nil) {
        CGRect frame = CGRectMake(198.0, 9.0, 94.0, 27.0);
        logSwitch = [[UISwitch alloc] initWithFrame:frame];
		
        [logSwitch addTarget:self action:@selector(logSwitchAction:) forControlEvents:UIControlEventValueChanged];
        
        // in case the parent view draws with a custom color or gradient, use a transparent color
        logSwitch.backgroundColor = [UIColor clearColor];
		
		logSwitch.tag = 2;	// tag this view for later so we can remove it from recycled table cells
    }
    return logSwitch;
}

#pragma mark Spinner Methods

- (void)showSpinnerViewInThread {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	self.tableView.contentOffset = CGPointMake(0, 0);
	[self.spinnerView show];
	[pool release];
}

- (void)hideSpinnerViewInThread {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self.spinnerView hide];
	[pool release];
}

- (void)showSpinnerView {
	self.view.userInteractionEnabled = NO;
	[NSThread detachNewThreadSelector:@selector(showSpinnerViewInThread) toTarget:self withObject:nil];
}

- (void)hideSpinnerView {
	self.view.userInteractionEnabled = YES;
	[NSThread detachNewThreadSelector:@selector(hideSpinnerViewInThread) toTarget:self withObject:nil];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	NSLog(@"showed an image!");
	UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
	UIImageView *iv = [[UIImageView alloc] initWithImage:image];
	RackspaceAppDelegate *app = (RackspaceAppDelegate *) [[UIApplication sharedApplication] delegate];
	[app.window addSubview:iv];
	
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:3.75];
	iv.alpha = 0.0;
	[UIView commitAnimations];
	
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	if ([folders count] > 0 && indexPath.section == kFolders) {
		ListFolderObjectsViewController *vc = [[ListFolderObjectsViewController alloc] initWithNibName:@"ListFolderObjectsViewController" bundle:nil];
		
		NSString *key = [[folders allKeys] objectAtIndex:indexPath.row];
		vc.title = key;
		vc.objects = [folders valueForKey:key];
		vc.filenamePrefixLength = [key length] + 1;
		vc.container = self.container;
		
		[self.navigationController pushViewController:vc animated:YES];
		[vc release];
		
	} else if (indexPath.section == kFiles || indexPath.section == kFolders) {
		
		CloudFilesObject *o = (CloudFilesObject *) [unfolderedObjects objectAtIndex:indexPath.row];	
		ObjectViewController *vc = [[ObjectViewController alloc] initWithNibName:@"ObjectView" bundle:nil];
		vc.cfObject = o;
		vc.container = self.container;
		[self.navigationController pushViewController:vc animated:YES];
		[vc release];
		[aTableView deselectRowAtIndexPath:indexPath animated:NO];
		
		
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	NSLog(@"cancel camera");
	[picker dismissModalViewControllerAnimated:YES];
	
}

- (void)addButtonPressed {
	AddObjectViewController *vc = [[AddObjectViewController alloc] initWithNibName:@"AddObject" bundle:nil];
	vc.listObjectsViewController = self;
	vc.account = self.account;
	vc.container = self.container;
	[self presentModalViewController:vc animated:YES];	
}

- (void)showCamera {
	//if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
		
		NSLog(@"time to show the camera");
		UIImagePickerController *camera = [[UIImagePickerController alloc] init];		
		camera.delegate = self;
		camera.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
		//camera.sourceType = UIImagePickerControllerSourceTypeCamera;
		[self presentModalViewController:camera animated:YES];
		
	//}
}

- (void)viewDidLoad {
    [super viewDidLoad];	

	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonPressed)];

	// show a rounded rect view
	self.spinnerView = [[RoundedRectView alloc] initWithDefaultFrame];
	[self.view addSubview:self.spinnerView];

}

- (void)viewWillAppear:(BOOL)animated {
	
	// set up the accelerometer for the "shake to refresh" feature
	[[UIAccelerometer sharedAccelerometer] setUpdateInterval:(1.0 / 25)];
	[[UIAccelerometer sharedAccelerometer] setDelegate:self];	
	
	self.navigationItem.title = self.containerName;
	[NSThread detachNewThreadSelector:@selector(loadObjects) toTarget:self withObject:nil];	
	[super viewWillAppear:animated];
}

#pragma mark -
#pragma mark Keyboard Methods

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	self.container.ttl = textField.text;
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	self.container.ttl = textField.text;
	[textField resignFirstResponder];
	
	[self showSpinnerView];
	
	Response *response = [self.container updateCdnAttributes:self.containersRootViewController.cdnAccount.containers];
	[self hideSpinnerView];
	
	NSLog(@"ttl return status code = %i", response.statusCode);
	
	if (![response isSuccess]) {
		[self showSaveError:response];
	} else {
		// refresh the container object against the CDN Management URL so we'll be sure to have
		// the right CDN URI to use for file previews, etc
		[self.container refreshCDNAttributes];
	}
	
	return YES;
}

#pragma mark -
#pragma mark Table Methods

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//	return 50;
//}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if ([folders count] > 0) {
		return 4;
	} else {
		return 3;
	}
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section {
	if (section == kContainerDetails) {
		return NSLocalizedString(@"Container Details", @"Container Details table section header");
	} else if (section == kCDN) {
		return NSLocalizedString(@"Content Delivery Network", @"CDN table section header");
	} else if ([folders count] > 0 && section == kFolders) {
		return NSLocalizedString(@"Folders", @"Folders");
	} else { //if (section == kFiles) {
		return NSLocalizedString(@"Files", @"Container Files table section header");
	}
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger rows = 0;
	if (section == kContainerDetails) {
		rows = 2;
	} else if (section == kCDN) {
		rows = 1;
	} else if ([folders count] > 0 && section == kFolders) {
		if (objectsLoaded) {
			rows = [folders count];
		} else {
			rows = 1;
		}
	} else { //if (section == kFiles) {		
		if (objectsLoaded) {
			rows = [unfolderedObjects count];
		} else {
			rows = 1;
		}
	}
	return rows;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	//NSLog(@"section: %i\t\trow: %i", indexPath.section, indexPath.row);
	
	if (self.ttlCell == nil) {
		self.ttlCell = [[TextFieldCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:@"NameCell"];
		self.ttlCell.textField.placeholder = @"86400";
		self.ttlCell.accessoryType = UITableViewCellAccessoryNone;		
		
		self.ttlCell.textField.keyboardType = UIKeyboardTypeDefault;
		self.ttlCell.textField.delegate = self;
		self.ttlCell.textField.returnKeyType = UIReturnKeyDone;
	}
	
	if (indexPath.section == kContainerDetails) {
		static NSString *CellIdentifier = @"ContainerDetailsCell";
		UITableViewCell *cell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = NSLocalizedString(@"Name", @"Container Name label");
				cell.detailTextLabel.text = self.container.name;
				break;
			case 1:
				cell.textLabel.text = NSLocalizedString(@"Size", @"Container Size label");
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", [self.container humanizedCount], [self.container humanizedBytes]];
				break;
		}
		
		return cell;

	} else if (indexPath.section == kCDN) {
		static NSString *CellIdentifier = @"CDNCell";
		UITableViewCell *cell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		
		static NSString *CDNSwitchCellIdentifier = @"CDNSwitchCell";
		UITableViewCell *cdnSwitchCell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:CDNSwitchCellIdentifier];
		if (cdnSwitchCell == nil) {
			cdnSwitchCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CDNSwitchCellIdentifier] autorelease];
			cdnSwitchCell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		
		static NSString *LogSwitchCellIdentifier = @"LogSwitchCell";
		UITableViewCell *logSwitchCell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:LogSwitchCellIdentifier];
		if (logSwitchCell == nil) {
			logSwitchCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LogSwitchCellIdentifier] autorelease];
			logSwitchCell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		
		static NSString *CDNURLCellIdentifier = @"CDNURLCell";
		cdnURLCell = (TextFieldCell *) [aTableView dequeueReusableCellWithIdentifier:CDNURLCellIdentifier];
		if (cdnURLCell == nil) {
			cdnURLCell = [[TextFieldCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CDNURLCellIdentifier];
			cdnURLCell.textField.delegate = self;
			
			// hide the clear button, since this field is not editable
			cdnURLCell.textField.clearButtonMode = UITextFieldViewModeNever;
			
			// move the text over a little bit
			CGRect labelRect = cdnURLCell.textLabel.frame;
			labelRect.origin.x -= 15;
			cdnURLCell.textLabel.frame = labelRect;
			
			CGRect textRect = cdnURLCell.textField.frame;
			textRect.origin.x += 10;
			textRect.size.width -= 10; // to prevent scrolling off the side
			cdnURLCell.textField.frame = textRect;
			
		}
		
		switch (indexPath.row) {
			case 0:
				cdnSwitchCell.textLabel.text = NSLocalizedString(@"Publish to CDN", @"Publish to CDN cell label");
				//cell.detailTextLabel.text = self.container.cdnEnabled;
				if (self.container.cdnEnabled && [self.container.cdnEnabled isEqualToString:@"True"]) {
					cdnSwitch.on = YES;
				}
				[cdnSwitchCell.contentView addSubview:self.cdnSwitch];
				return cdnSwitchCell;
				break;
			case -1: // don't show.  perhaps bring this back later
				logSwitchCell.textLabel.text = NSLocalizedString(@"Log Retention", @"Log Retention cell label");
				//cell.detailTextLabel.text = self.container.logRetention;
				if (self.container.logRetention && [self.container.logRetention isEqualToString:@"True"]) {
					logSwitch.on = YES;
				}
				[logSwitchCell.contentView addSubview:self.logSwitch];
				return logSwitchCell;
				break;
			case 1:
				ttlCell.textLabel.text = NSLocalizedString(@"TTL", @"TTL cell label");
				ttlCell.textField.text = self.container.ttl;
				return ttlCell;
				break;
			case 3:
				cdnURLCell.textLabel.text = NSLocalizedString(@"CDN URL", @"CDN URL label");
				cdnURLCell.textField.text = self.container.cdnUrl;
				return cdnURLCell;
				break;
		}
		
		return cell;			
			
	} else if ([folders count] > 0 && indexPath.section == kFolders) {
		if (objectsLoaded) {
			
			UITableViewCell *cell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:@"FolderCell"];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"FolderCell"] autorelease];
				cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			}
			
			NSString *key = [[folders allKeys] objectAtIndex:indexPath.row];
			NSInteger count = [[folders objectForKey:key] count];
			cell.textLabel.text = key;
			if (count == 1) {
				cell.detailTextLabel.text = [NSString stringWithFormat:@"1 %@", NSLocalizedString(@"file", @"file")];
			} else {
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%i %@", count, NSLocalizedString(@"files", @"files")];
			}
			
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			return cell;
			
		} else { // show the spinner cell
			GroupSpinnerCell *cell = (GroupSpinnerCell *) [aTableView dequeueReusableCellWithIdentifier:@"SpinnerCell"];
			if (cell == nil) {
				cell = [[[GroupSpinnerCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SpinnerCell"] autorelease];
				cell.userInteractionEnabled = NO;
				self.tableView.userInteractionEnabled = NO;
			}
			
			return cell;
		}
	} else { //if (indexPath.section == kFiles) {
		if (objectsLoaded) {
			
			UITableViewCell *cell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:@"ObjectCell"];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ObjectCell"] autorelease];
				cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			}
			
			CloudFilesObject *o = (CloudFilesObject *) [unfolderedObjects objectAtIndex:indexPath.row];	
			cell.textLabel.text = o.name;
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", o.contentType, [o humanizedBytes]];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			return cell;
			
		} else { // show the spinner cell
			GroupSpinnerCell *cell = (GroupSpinnerCell *) [aTableView dequeueReusableCellWithIdentifier:@"SpinnerCell"];
			if (cell == nil) {
				cell = [[[GroupSpinnerCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"SpinnerCell"] autorelease];
				cell.userInteractionEnabled = NO;
				self.tableView.userInteractionEnabled = NO;
			}
			
			return cell;
		}
	} 
	return nil;
}

#pragma mark -
#pragma mark Refresh File List

- (void) refreshFileList {
	objectsLoaded = NO;
	[self.tableView reloadData];		
	[NSThread detachNewThreadSelector:@selector(loadObjects) toTarget:self withObject:nil];	
}

#pragma mark Shake Feature
- (void) accelerometer:(UIAccelerometer*)accelerometer didAccelerate:(UIAcceleration*)acceleration {
	UIAccelerationValue length, x, y, z;
	
	// Use a basic high-pass filter to remove the influence of the gravity
	myAccelerometer[0] = acceleration.x * 0.1 + myAccelerometer[0] * (1.0 - 0.1);
	myAccelerometer[1] = acceleration.y * 0.1 + myAccelerometer[1] * (1.0 - 0.1);
	myAccelerometer[2] = acceleration.z * 0.1 + myAccelerometer[2] * (1.0 - 0.1);
	// Compute values for the three axes of the acceleromater
	x = acceleration.x - myAccelerometer[0];
	y = acceleration.y - myAccelerometer[1];
	z = acceleration.z - myAccelerometer[2];
	
	// Compute the intensity of the current acceleration 
	length = sqrt(x * x + y * y + z * z);
	
	// see if they shook hard enough to refresh
	if (length >= 3.0) {
		[self refreshFileList];		
	}
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.objectsContainer = nil;
	objectsLoaded = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
	self.objectsContainer = nil;
	objectsLoaded = NO;
	[super viewDidDisappear:animated];
}

- (void)dealloc {
	[account release];
	[container release];
	[containerName release];
	[cdnSwitch release];
	[logSwitch release];
	[spinnerView release];
	[objectsContainer release];
	[ttlCell release];
	if (folderedObjects) {
		[folderedObjects release];
	}
	if (unfolderedObjects) {
		[unfolderedObjects release];
	}
	[containersRootViewController release];
    [super dealloc];
}


@end
