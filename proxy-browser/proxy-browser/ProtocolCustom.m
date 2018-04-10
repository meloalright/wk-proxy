//
//  ProtocolCustom.m
//  proxy-browser
//
//  Created by melo的苹果本 on 2018/4/8.
//  Copyright © 2018年 com. All rights reserved.
//
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

static NSString*const matchingPrefix = @"http://10.2.138.225:3233/static";
static NSString*const regPrefix = @"http://10.2.138.225:3233";
static NSString* tmpURL = @"";
static NSString*const FilteredKey = @"FilteredKey";


@interface FilteredProtocol : NSURLProtocol
@property (nonatomic, strong) NSMutableData   *responseData;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation FilteredProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [NSURLProtocol propertyForKey:FilteredKey inRequest:request]== nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSLog(@"Got it request.URL.absoluteString = %@",request.URL.absoluteString);

    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    //截取重定向
    if ([request.URL.absoluteString hasPrefix:matchingPrefix])
    {
        NSURL* proxyURL = [NSURL URLWithString:[FilteredProtocol generateProxyPath: request.URL.absoluteString]];
        NSLog(@"Proxy to = %@", proxyURL);
        mutableReqeust = [NSMutableURLRequest requestWithURL: proxyURL];
    }
    return mutableReqeust;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    //标示改request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:FilteredKey inRequest:mutableReqeust];
    self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
    
}

- (void)stopLoading
{
    if (self.connection != nil)
    {
        [self.connection cancel];
        self.connection = nil;
    }
}
#pragma mark- NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseData = [[NSMutableData alloc] init];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

+ (NSString *)generateProxyPath:(NSString *) absoluteURL {
    NSString *cacheFilePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dist"];
    NSString *fileURL = [@"file:/" stringByAppendingString: tmpFilePath];

    [fm removeItemAtPath:tmpFilePath error:nil];
    NSError *saveError;
    //读取前先从caches拷贝到tmp临时文件夹
    [[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:[cacheFilePath stringByAppendingPathComponent:@"dist"]] toURL:[NSURL fileURLWithPath:tmpFilePath] error:&saveError];
    NSLog(@"copy ok");
    return [absoluteURL stringByReplacingOccurrencesOfString:regPrefix
                                                 withString:fileURL];
}
@end

