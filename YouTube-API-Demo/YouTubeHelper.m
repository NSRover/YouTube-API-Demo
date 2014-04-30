//
//  YouTubeHelper.m
//  YouTube_iOS_API_Sample
//
//  Created by Nirbhay Agarwal on 17/04/14.
//  Copyright (c) 2014 Nirbhay Agarwal. All rights reserved.
//

#import "YouTubeHelper.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "GTMHTTPUploadFetcher.h"

@interface YouTubeHelper ()

@property (strong) GTLServiceYouTube *youTubeService;

@property (strong) GTLServiceTicket *channelListTicket;
@property (strong) GTLYouTubeChannelContentDetailsRelatedPlaylists *playlists;
@property (strong) GTLServiceTicket *playlistItemListTicket;
@property (strong) GTLYouTubePlaylistItemListResponse *playlistItemList;
@property (strong) GTLServiceTicket *uploadFileTicket;

@property (strong) NSString* videoTitle;
@property (strong) NSString* videoDescription;
@property (strong) NSString* videoTags;
@property (strong) NSString* videoPath;

@property (strong) NSString* clientID;
@property (strong) NSString* clientSecret;

@end

static NSString* kKeychainItemName = @"YoutubeHelper";

@implementation YouTubeHelper

#pragma mark Initialization

- (id)initWithDelegate:(id <YouTubeHelperDelegate>)delegate {
    self = [super init];
    
    self.delegate = delegate;
    [self initYoutubeService];
    
    return self;
}

- (id)init {
    NSLog(@"YouTubeHelper: Use the initWithDelegate: method instead of init");
    return nil;
}

#pragma mark Public

- (void)authenticate {
    //Get auth object from keychain if available
    [self storedAuth];
    
    //Check if auth was valid
    if (![self isAuthValid]) {
        if ([self hasViewController]) {
            [self showOAuthSignInView];
        }
    }
}

- (void)signOut {
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
}

- (void)getUploadedPlaylist {
    
    if ([self isAuthValid]) {
        [self getChannelList];
    }
    else
    {
        NSLog(@"YouTubeHelper: User not authenticated yet.");
    }
}

- (void)uploadPrivateVideoWithTitle:(NSString *)title description:(NSString *)description commaSeperatedTags:(NSString *)tags andPath:(NSString *)path {
    
    if (![self isAuthValid]) {
        NSLog(@"YouTubeHelper: User not authenticated yet.");
        return;
    }
    
    if (!title) {
        NSLog(@"Title missing");
        return;
    }
    else
    {
        self.videoTitle = title;
    }
    
    self.videoDescription = description;
    
    self.videoTags = tags;
    
    if (!path) {
        NSLog(@"Video path missing");
    }
    else
    {
        self.videoPath = path;
    }
    
    [self prepareUploadVideo];
}

#pragma mark Misk Tasks

- (BOOL)hasViewController {
    if (_delegate && [_delegate respondsToSelector:@selector(showAuthenticationViewController:)])
    {
        return YES;
    }
    return NO;
}

- (void)returnUploadedPlaylist {
    if (_delegate && [_delegate respondsToSelector:@selector(uploadedVideosPlaylist:)]) {
        [_delegate uploadedVideosPlaylist:_playlistItemList.items];
    }
}

- (NSString *)MIMETypeForFilename:(NSString *)filename
                  defaultMIMEType:(NSString *)defaultType {
    NSString *result = defaultType;
    NSString *extension = [filename pathExtension];
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                            (__bridge CFStringRef)extension, NULL);
    if (uti) {
        CFStringRef cfMIMEType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
        if (cfMIMEType) {
            result = CFBridgingRelease(cfMIMEType);
        }
        CFRelease(uti);
    }
    return result;
}

- (BOOL)isAuthValid {
    if (!((GTMOAuth2Authentication *)_youTubeService.authorizer).canAuthorize) {
        return NO;
    }
    return YES;
}

#pragma mark Tasks

- (BOOL)initYoutubeService {
    
    self.youTubeService = [[GTLServiceYouTube alloc] init];
    _youTubeService.shouldFetchNextPages = YES;
    _youTubeService.retryEnabled = YES;
    
    //Client id
    if (_delegate && [_delegate respondsToSelector:@selector(youtubeAPIClientID)]) {
        self.clientID = [_delegate youtubeAPIClientID];
    }
    else
    {
        NSLog(@"YouTube Helper: Client ID not provided, please implement the required delegate method");
    }
    
    //Client Secret
    if (_delegate && [_delegate respondsToSelector:@selector(youtubeAPIClientSecret)]) {
        self.clientSecret = [_delegate youtubeAPIClientSecret];
    }
    else
    {
        NSLog(@"YouTube Helper: Client Secret not provided, please implement the required delegate method");
    }
    
    return YES;
}

- (void)storedAuth {
    _youTubeService.authorizer =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                       clientID:_clientID
                                                      clientSecret:_clientSecret];
}

- (void)showOAuthSignInView {
    // Show the OAuth 2 sign-in controller.
    GTMOAuth2ViewControllerTouch *viewController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeYouTube
                                                                                               clientID:_clientID
                                                                                           clientSecret:_clientSecret
                                                                                       keychainItemName:kKeychainItemName
                                                                                              delegate:self
                                                                                      finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    
    [_delegate showAuthenticationViewController:viewController];
//    [_currentViewController presentViewController:viewController animated:YES completion:nil];
//    [_currentViewController.navigationController pushViewController:viewController animated:YES];
}

- (void)getChannelList {
    self.playlists = nil;
    
    GTLServiceYouTube *service = self.youTubeService;
    
    GTLQueryYouTube *query = [GTLQueryYouTube queryForChannelsListWithPart:@"contentDetails"];
    query.mine = YES;
    query.maxResults = 50;
    // query.fields = @"kind,etag,items(id,etag,kind,contentDetails)";
    
    self.channelListTicket = [service executeQuery:query
                             completionHandler:^(GTLServiceTicket *ticket,
                                                 GTLYouTubeChannelListResponse *channelList,
                                                 NSError *error) {
                                 if ([[channelList items] count] > 0) {
                                     GTLYouTubeChannel *channel = channelList[0];
                                     self.playlists = channel.contentDetails.relatedPlaylists;
                                 }
                                 
                                 if (_playlists) {
                                     [self getPlaylist];
                                 }
                                 else
                                 {
                                     NSLog(@"Unable to get channels info");
                                 }
                             }];
}

- (void)getPlaylist {
    NSString *playlistID = _playlists.uploads;
    
    if ([playlistID length] > 0) {
        GTLServiceYouTube *service = self.youTubeService;
        
        GTLQueryYouTube *query = [GTLQueryYouTube queryForPlaylistItemsListWithPart:@"snippet,contentDetails"];
        query.playlistId = playlistID;
        query.maxResults = 50;
        
        self.playlistItemListTicket = [service executeQuery:query
                                      completionHandler:^(GTLServiceTicket *ticket,
                                                          GTLYouTubePlaylistItemListResponse *playlistItemList,
                                                          NSError *error) {
                                          // Callback
                                          self.playlistItemList = playlistItemList;
                                          
                                          [self returnUploadedPlaylist];
                                      }];
    }
    else
    {
        self.playlists = nil;
    }
}

- (void)prepareUploadVideo {
    
    // Status.
    GTLYouTubeVideoStatus *status = [GTLYouTubeVideoStatus object];
    status.privacyStatus = @"private";
    
    // Snippet.
    GTLYouTubeVideoSnippet *snippet = [GTLYouTubeVideoSnippet object];
    snippet.title = _videoTitle;
    if ([_videoDescription length] > 0) {
        snippet.descriptionProperty = _videoDescription;
    }
    if ([_videoTags length] > 0) {
        snippet.tags = [_videoTags componentsSeparatedByString:@","];
    }
//    if ([_uploadCategoryPopup isEnabled]) {
//        NSMenuItem *selectedCategory = [_uploadCategoryPopup selectedItem];
//        snippet.categoryId = [selectedCategory representedObject];
//    }
    
    GTLYouTubeVideo *video = [GTLYouTubeVideo object];
    video.status = status;
    video.snippet = snippet;
    
    [self uploadVideoWithVideoObject:video
             resumeUploadLocationURL:nil];
}

- (void)uploadVideoWithVideoObject:(GTLYouTubeVideo *)video
           resumeUploadLocationURL:(NSURL *)locationURL {
    // Get a file handle for the upload data.
    NSString *path = _videoPath;
    NSString *filename = [path lastPathComponent];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (fileHandle) {
        NSString *mimeType = [self MIMETypeForFilename:filename
                                       defaultMIMEType:@"video/mp4"];
        GTLUploadParameters *uploadParameters =
        [GTLUploadParameters uploadParametersWithFileHandle:fileHandle
                                                   MIMEType:mimeType];
        uploadParameters.uploadLocationURL = locationURL;
        
        GTLQueryYouTube *query = [GTLQueryYouTube queryForVideosInsertWithObject:video
                                                                            part:@"snippet,status"
                                                                uploadParameters:uploadParameters];
        
        GTLServiceYouTube *service = self.youTubeService;
        
        
        self.uploadFileTicket = [service executeQuery:query
                                completionHandler:^(GTLServiceTicket *ticket,
                                                    GTLYouTubeVideo *uploadedVideo,
                                                    NSError *error) {
                                    // Callback
                                    _uploadFileTicket = nil;
                                    if (error == nil) {
                                        NSLog(@"Video Uploaded : %@", uploadedVideo.snippet.title);
                        
                                    } else {
                                        NSLog(@"Video Upload failed : %@", [error description]);
                                    }
                                }];
        
        __weak YouTubeHelper *dummySelf = self;
        _uploadFileTicket.uploadProgressBlock = ^(GTLServiceTicket *ticket,
                                                  unsigned long long numberOfBytesRead,
                                                  unsigned long long dataLength) {
            
            long double division = (double)numberOfBytesRead / (double)dataLength;
            int percentage = division * 100;
            
            if (dummySelf.delegate && [dummySelf.delegate respondsToSelector:@selector(uploadProgressPercentage:)]) {
                [dummySelf.delegate uploadProgressPercentage:percentage];
            }
        };
        
        // To allow restarting after stopping, we need to track the upload location
        // URL.
        //
        // For compatibility with systems that do not support Objective-C blocks
        // (iOS 3 and Mac OS X 10.5), the location URL may also be obtained in the
        // progress callback as ((GTMHTTPUploadFetcher *)[ticket objectFetcher]).locationURL
        
//        GTMHTTPUploadFetcher *uploadFetcher = (GTMHTTPUploadFetcher *)[_uploadFileTicket objectFetcher];
//        uploadFetcher.locationChangeBlock = ^(NSURL *url) {
//            _uploadLocationURL = url;
//            [self updateUI];
//        };
    } else {
        NSLog(@"YouTube Helper: invalid/missing file at location provided %@", path);
    }
}

#pragma mark Auth Delegate

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
    
    //Inform delegate
    if (_delegate && [_delegate respondsToSelector:@selector(authenticationEndedWithError:)]) {
        [_delegate authenticationEndedWithError:error];
    }
    
    //If no error, assign to instance variable
    if (error == nil) {
        _youTubeService.authorizer = auth;
    }
}

@end
