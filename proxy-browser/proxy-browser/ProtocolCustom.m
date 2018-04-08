//
//  ProtocolCustom.m
//  proxy-browser
//
//  Created by melo的苹果本 on 2018/4/8.
//  Copyright © 2018年 com. All rights reserved.
//
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

static NSString*const sourUrl  = @"https://29e5534ea20a8.cdn.sohucs.com/mobile/sohu-logo-d.png";
static NSString* localUrl = @"https://m.baidu.com/static/index/plus/plus_logo.png";
//static NSString* localUrl = @"file://private/var/mobile/Containers/Data/Application/xxxxx/tmp/qihoo.png";
static NSString*const FilteredCssKey = @"filteredCssKey";


@interface FilteredProtocol : NSURLProtocol
@property (nonatomic, strong) NSMutableData   *responseData;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation FilteredProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSLog(@"request.URL.absoluteString = %@",request.URL.absoluteString);
    NSLog(@"\n");
    return [NSURLProtocol propertyForKey:FilteredCssKey inRequest:request]== nil;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    NSLog(@"Got it request.URL.absoluteString = %@",request.URL.absoluteString);
    NSLog(@"\n");
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    //截取重定向
    if ([request.URL.absoluteString isEqualToString:sourUrl])
    {
        NSURL* url1 = [NSURL URLWithString:localUrl];
        NSLog(@"Proxy to = %@",localUrl);
        mutableReqeust = [NSMutableURLRequest requestWithURL:url1];
    }
    return mutableReqeust;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    localUrl = [self setProxyLocalPath];
    //标示改request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:FilteredCssKey inRequest:mutableReqeust];
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

- (NSString *)setProxyLocalPath {
        NSString *cachewww = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *tmpwww = [NSTemporaryDirectory() stringByAppendingPathComponent:@"qihoo.png"];
        [fm removeItemAtPath:tmpwww error:nil];
        
        NSError *saveError;
        //读取前先从caches拷贝到tmp临时文件夹
        [[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:[cachewww stringByAppendingPathComponent:@"qihoo.png"]] toURL:[NSURL fileURLWithPath:tmpwww] error:&saveError];
    return [@"file:/" stringByAppendingString:tmpwww];
}
@end

