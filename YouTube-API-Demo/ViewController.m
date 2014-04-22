//
//  ViewController.m
//  YouTube_iOS_API_Sample
//
//  Created by Nirbhay Agarwal on 17/04/14.
//  Copyright (c) 2014 Nirbhay Agarwal. All rights reserved.
//

#import "ViewController.h"

#import "GTLYouTube.h"

@interface ViewController ()

@property (strong) YouTubeHelper *youtubeHelper;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.youtubeHelper = [[YouTubeHelper alloc] initWithDelegate:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)playlistButtonTapped:(id)sender {
    [_youtubeHelper getUploadedPlaylist];
}

- (IBAction)uploadVideoTapped:(id)sender {
    NSString* videoPath = [[NSBundle mainBundle] pathForResource:@"Sample" ofType:@"mov"];
    [_youtubeHelper uploadPrivateVideoWithTitle:@"4 Video Title"
                                    description:@"4 Video Description"
                             commaSeperatedTags:@"4 VideoTag1, 4 VideoTag2"
                                        andPath:videoPath];
}

- (IBAction)authenticateTapped:(id)sender {
    [_youtubeHelper authenticate];
}

#pragma mark YouTubeHelper Delegate

- (NSString *)youtubeAPIClientID
{
    return @"1082647846628-068atd3gmj1f78rb55e2s1360spoi69d.apps.googleusercontent.com";
}

- (NSString *)youtubeAPIClientSecret
{
    return @"6RjS-cH8uXI1qTtyJzUJGyFU";
}

- (void)showAuthenticationViewController:(UIViewController *)authView;
{
    [self.navigationController pushViewController:authView animated:YES];
}

- (void)authenticationEndedWithError:(NSError *)error;
{
    NSLog(@"Error %@", error.description);
}

- (void)uploadedVideosPlaylist:(NSArray *)array;
{
    NSLog(@"uploaded list:");
    for (int ii = 0; ii < array.count; ii++) {
        GTLYouTubePlaylistItem* item = array[ii];
        NSLog(@"    %@", item.snippet.title);
    }
}

- (void)uploadProgressPercentage:(int)percentage;
{
    NSLog(@"    Data uploaded: %d", percentage);
}

@end
