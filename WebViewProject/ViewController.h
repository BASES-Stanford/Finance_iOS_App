//
//  ViewController.h
//  WebViewProject
//
//  Created by Ryan Matsumoto on 11/2/14.
//  Copyright (c) 2014 BASES. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"

#import <AssetsLibrary/AssetsLibrary.h>



@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UITextFieldDelegate> {
    IBOutlet UIScrollView *scroller;
}


-(NSString *)receiptName;
-(void)setReceiptName:(NSString *)receiptName;
@property (nonatomic, strong) IBOutlet UIWebView *webView;
@property (nonatomic, retain) GTLServiceDrive *driveService;


@end

