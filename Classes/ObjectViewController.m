//
//  ObjectViewController.m
//  Rackspace
//
//  Created by Michael Mayo on 7/3/09.
//  Copyright 2009 Rackspace Hosting. All rights reserved.
//

#import "ObjectViewController.h"
#import "CloudFilesObject.h"
#import "WebFileViewController.h"
#import "Container.h"
#import "SpinnerAccessoryCell.h"
#import "RackspaceAppDelegate.h"

#define kFileDetails 0
#define kActions 1

@implementation ObjectViewController

@synthesize cfObject, container;

- (void)viewWillAppear:(BOOL)animated {
	self.navigationItem.title = self.cfObject.name;
	[super viewWillAppear:animated];
}

#pragma mark Table Methods

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section {
	if (section == kFileDetails) {
		return @"File Details";
	} else {
		return @"";
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if ([self.container.cdnEnabled isEqualToString:@"True"]) {
		return 2;
	} else {
		return 1;
	}
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == kFileDetails) {
		return 3;
	} else if (section == kActions) {
		//if ([MFMailComposeViewController canSendMail]) {
			return 3;
//		} else {
//			return 1;
//		}
	} else {
		return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if (indexPath.section == kFileDetails) {
		
		static NSString *CellIdentifier = @"FileDetailsCell";
		UITableViewCell *cell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier] autorelease];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = @"Name";
				cell.detailTextLabel.text = self.cfObject.name;
				break;
			case 1:
				cell.textLabel.text = @"Size";
				cell.detailTextLabel.text = [self.cfObject humanizedBytes];
				break;
			case 2:
				cell.textLabel.text = @"File Type";
				cell.detailTextLabel.text = self.cfObject.contentType;
				break;
			case 3:
				cell.textLabel.text = @"Object";
				cell.detailTextLabel.text = self.cfObject.object;
				break;
		}
		
		return cell;
		
	} else if (indexPath.section == kActions) {
		static NSString *CellIdentifier = @"FileActionCell";
		UITableViewCell *cell = (UITableViewCell *) [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		
		static NSString *AttachCellIdentifier = @"AttachCell";
		SpinnerAccessoryCell *attachCell = (SpinnerAccessoryCell *) [aTableView dequeueReusableCellWithIdentifier:AttachCellIdentifier];
		if (attachCell == nil) {
			attachCell = [[[SpinnerAccessoryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AttachCellIdentifier] autorelease];
			attachCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;			
		}
		
		switch (indexPath.row) {
			case 0:
				cell.textLabel.text = @"Preview File";
				break;
			case 1:
				cell.textLabel.text = @"Email Link to File";
				break;
			case 2:
				attachCell.textLabel.text = @"Email File as Attachment";
				return attachCell;
				break;
			default:
				break;
		}
		return cell;
	} else {
		return nil;
	}
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == 0) { // preview the file		
		if ([self.cfObject.contentType isEqualToString:@"application/octet-stream"]
				|| ((NSRange) [self.cfObject.contentType rangeOfString:@"video/"]).location == 0) {
			// let's assume it's audio or video... try and play it!
			RackspaceAppDelegate *app = (RackspaceAppDelegate *) [[UIApplication sharedApplication] delegate];
			NSString *urlString = [NSString stringWithFormat:@"%@/%@", self.container.cdnUrl, self.cfObject.name];
			NSURL *url = [[NSURL alloc] initWithString:urlString];
			[app initAndPlayMovie:url];
		} else {
			WebFileViewController *vc = [[WebFileViewController alloc] initWithNibName:@"WebFileViewController" bundle:nil];
			vc.cfObject = self.cfObject;
			vc.container = self.container;
			[self.navigationController pushViewController:vc animated:YES];
			[vc release];
			[aTableView deselectRowAtIndexPath:indexPath animated:NO];		
		}
	} else if (indexPath.row == 1) { // email a link
		MFMailComposeViewController *vc = [[MFMailComposeViewController alloc] init];
		vc.mailComposeDelegate = self;		
		[vc setSubject:self.cfObject.name];
		NSString *emailBody = [NSString stringWithFormat:@"%@/%@", self.container.cdnUrl, self.cfObject.name];
		[vc setMessageBody:emailBody isHTML:NO];
		
		[self presentModalViewController:vc animated:YES];
		[vc release];
		
	} else if (indexPath.row == 2) { // email as attachment
		
		[aTableView reloadData];
		
		MFMailComposeViewController *vc = [[MFMailComposeViewController alloc] init];
		vc.mailComposeDelegate = self;
		
		[vc setSubject:self.cfObject.name];
		
		// Attach an image to the email
		//		NSString *path = [[NSBundle mainBundle] pathForResource:@"rainy" ofType:@"png"];
		//		NSData *myData = [NSData dataWithContentsOfFile:path];
		//		[vc addAttachmentData:myData mimeType:@"image/png" fileName:@"rainy"];
		NSString *urlString = [NSString stringWithFormat:@"%@/%@", self.container.cdnUrl, self.cfObject.name];
		NSURL *url = [NSURL URLWithString:urlString];
		NSData *attachmentData = [NSData dataWithContentsOfURL:url];
		[vc addAttachmentData:attachmentData mimeType:self.cfObject.contentType fileName:self.cfObject.name];
		
		// Fill out the email body text
		NSString *emailBody = @"";
		[vc setMessageBody:emailBody isHTML:NO];
		
		[self presentModalViewController:vc animated:YES];
		[vc release];
	}
}

#pragma mark Mail Composer Delegate Methods

// Dismisses the email composition interface when users tap Cancel or Send.
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {	
	[self dismissModalViewControllerAnimated:YES];
}


#pragma mark Memory Management

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[cfObject release];
	[container release];
    [super dealloc];
}


@end
