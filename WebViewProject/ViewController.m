//
//  ViewController.m
//  WebViewProject
//
//  Created by Ryan Matsumoto on 11/2/14.
//  Copyright (c) 2014 BASES. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
    CGPoint svos;
}
@property (weak, nonatomic) IBOutlet UITextField *receiptNameTextField;
@property(nonatomic) NSString *receiptName;
@end

static NSString *const kKeychainItemName = @"Google Drive Quickstart";
static NSString *const kClientID = @"334252154818-b71rhhnealb8vq27m2da7t02sgi7ff05.apps.googleusercontent.com";
static NSString *const kClientSecret = @"Ayphui8bMMr9_L26BFoJrmyT";

@implementation ViewController
@synthesize webView;
@synthesize driveService;

- (void)viewDidLoad {
    NSURL *url = [NSURL URLWithString:@"https://docs.google.com/forms/d/1dGlFf8WHeIo7sGqeLUGitQUi6dh_GcYI6horMI_oS0I/viewform"];
    NSURLRequest *requestURL= [NSURLRequest requestWithURL:url];
    [webView loadRequest:requestURL];
    [super viewDidLoad];
    webView.scalesPageToFit = YES;
    // webView size set by constraints
    //webView.frame = CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height*.5);
        // Do any additional setup after loading the view, typically from a nib.
    [self.receiptNameTextField setDelegate: self];
    
    
    // Initialize the drive service & load existing credentials from the keychain if available
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];

     [self.receiptNameTextField setReturnKeyType:UIReturnKeyDone];
    _receiptName = @"";
    
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    
    // Code that forces app to request access to photos from home screen (to avoid conflict between alert and Auth view)
    [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        NSLog(@"%i",[group numberOfAssets]);
    } failureBlock:^(NSError *error) {
        if (error.code == ALAssetsLibraryAccessUserDeniedError) {
            NSLog(@"user denied access, code: %i",error.code);
        }else{
            NSLog(@"Other error code: %i",error.code);
        }
    }];
    
}

- (void) viewDidLayoutSubviews {
    [scroller setScrollEnabled:YES];
    [scroller setContentSize:CGSizeMake(self.view.frame.size.width, self.view.frame.size.height + 500)];
}

// Allows scrolling so keyboard does not hide textfield
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    svos = scroller.contentOffset;
    CGPoint pt;
    CGRect rc = [textField bounds];
    rc = [textField convertRect:rc toView:scroller];
    pt = rc.origin;
    pt.x = 0;
    pt.y -= 60;
    [scroller setContentOffset:pt animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Set variable for receipt name text field
- (IBAction)receiptNameTextField:(UITextField*) sender {
    _receiptName = sender.text;
}

- (IBAction)takePhotoOfReceipt:(id)sender {
    [self showCamera:TRUE];
}

- (IBAction)chooseReceiptImage:(id)sender {
    [self showCamera:FALSE];
}

- (void)showCamera:(bool)takePhoto
{
    if ([_receiptName isEqualToString:@""]) {
        [self showAlert:@"Missing Receipt Name!" message:@"Please name your receipt before uploading a photo."];
        return;
    }
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    
    if (takePhoto && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    else
    {
        // In case we're running the iPhone simulator, fall back on the photo library instead.
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            [self showAlert:@"Error" message:@"Sorry, iPad Simulator not supported!"];
            return;
        }
    };
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    cameraUI.allowsEditing = YES;
    cameraUI.delegate = self;
    [self presentViewController:cameraUI animated:YES completion:nil];
    [cameraUI setNavigationBarHidden:FALSE];
    if (![self isAuthorized])
    {
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        [cameraUI pushViewController:[self createAuthController] animated:YES];
    }

}


// Handle selection of an image
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self uploadPhoto:image];
}

// Handle cancel from image picker/camera.
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    return [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];
}

// Creates the auth controller for authorizing access to Google Drive.
- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    GTMOAuth2ViewControllerTouch *authController;
    authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDrive
                                                                clientID:kClientID
                                                            clientSecret:kClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

// Handle completion of the authorization process, and updates the Drive service
// with the new credentials.
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)authResult
                 error:(NSError *)error
{
    if (error != nil)
    {
        [self showAlert:@"Authentication Error" message:error.localizedDescription];
        self.driveService.authorizer = nil;
    }
    else
    {
        self.driveService.authorizer = authResult;
    }
}

// Uploads a photo to Google Drive
- (void)uploadPhoto:(UIImage*)image
{
    UIAlertView *waitIndicator = [self showWaitIndicator:@"Uploading to Google Drive"];
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = _receiptName;
    file.descriptionProperty = @"Uploaded from the BASES Finance iOS app";
    file.mimeType = @"image/png";
    
    // Find BASES Finance Receipt Images Folder
    GTLQueryDrive *folderQuery = [GTLQueryDrive queryForFilesList];
    
    // Getting month/year for folder purposes
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger month = [components month];
    NSInteger year = [components year];
    NSString* folderMonthYear = [NSString stringWithFormat:@"%ld_%ld_BASES", (long)month, (long)year];
    NSLog(@"Folder name is %@", folderMonthYear);
    
    NSString *queryString = [NSString stringWithFormat: @"mimeType='application/vnd.google-apps.folder' and trashed=false and title='%@'", folderMonthYear];
    folderQuery.q = queryString;
    [self.driveService executeQuery:folderQuery completionHandler:^(GTLServiceTicket *ticket,
                                                                    GTLDriveFileList *files,
                                                                    NSError *error) {
        if (error == nil) {
            if (files.items) {
                // Set up parent folder (BASES Finance Receipt Images)
                NSLog(@"Folders found: %@", files.items[0]);
                GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                GTLDriveFile *ourFolder = files.items[0];
                parentRef.identifier = ourFolder.identifier;
                NSLog(@"Parent identifier: %@", parentRef.identifier);
                file.parents = [NSArray arrayWithObject:parentRef];
                
                // Create a query to send the image to Google Drive folder
                NSData *data = UIImagePNGRepresentation((UIImage *)image);
                GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data MIMEType:file.mimeType];
                GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                                   uploadParameters:uploadParameters];
                
                
                [self.driveService executeQuery:query
                              completionHandler:^(GTLServiceTicket *ticket,
                                                  GTLDriveFile *insertedFile, NSError *error) {
                                  [waitIndicator dismissWithClickedButtonIndex:0 animated:YES];
                                  if (error == nil)
                                  {
                                      NSLog(@"File ID: %@", insertedFile.identifier);
                                      [self showAlert:@"Google Drive" message:@"File saved!"];
                                  }
                                  else
                                  {
                                      NSLog(@"An error occurred: %@", error);
                                      [self showAlert:@"Google Drive" message:@"Sorry, an error occurred!"];
                                  }
                              }];
                
            } else
                [self showAlert:@"Google Drive" message:@"Google drive folder not found!"];
            
        } else {
            [self showAlert:@"Google Drive" message:@"Sorry, an error occurred!"];
        }
    }];
    
    
}


// Helper for showing a wait indicator in a popup
- (UIAlertView*)showWaitIndicator:(NSString *)title
{
    UIAlertView *progressAlert;
    progressAlert = [[UIAlertView alloc] initWithTitle:title
                                               message:@"Please wait..."
                                              delegate:nil
                                     cancelButtonTitle:nil
                                     otherButtonTitles:nil];
    [progressAlert show];
    
    UIActivityIndicatorView *activityView;
    activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityView.center = CGPointMake(progressAlert.bounds.size.width / 2,
                                      progressAlert.bounds.size.height - 45);
    
    [progressAlert addSubview:activityView];
    [activityView startAnimating];
    return progressAlert;
}

// Helper for showing an alert
- (void)showAlert:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert;
    alert = [[UIAlertView alloc] initWithTitle: title
                                       message: message
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
    [alert show];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}




@end
