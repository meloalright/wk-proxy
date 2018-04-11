//
//  ProtocolCustom.m
//  proxy-browser
//
//  Created by melo的苹果本 on 2018/4/8.
//  Copyright © 2018年 com. All rights reserved.
//
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

static NSString*const matchingPrefix = @"http://10.2.138.225:3233/static/";
static NSString*const regPrefix = @"http://10.2.138.225:3233";
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
    // 标示改request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:FilteredKey inRequest:mutableReqeust];
    
    if ([self.request.URL.absoluteString hasSuffix:@"index.html"]) {

        NSURL *url = self.request.URL;
 
        NSString *path = [FilteredProtocol generateDateReadPath: self.request.URL.absoluteString];
        
        NSLog(@"Read data from path = %@", path);
        NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
        NSData *data = [file readDataToEndOfFile];
        NSLog(@"Got data = %@", data);
        [file closeFile];
        
        //3.拼接响应Response
        NSInteger dataLength = data.length;
        NSString *mimeType = [self getMIMETypeWithCAPIAtFilePath:path];
        NSString *httpVersion = @"HTTP/1.1";
        NSHTTPURLResponse *response = nil;
        
        if (dataLength > 0) {
            response = [self jointResponseWithData:data dataLength:dataLength mimeType:mimeType requestUrl:url statusCode:200 httpVersion:httpVersion];
        } else {
            response = [self jointResponseWithData:[@"404" dataUsingEncoding:NSUTF8StringEncoding] dataLength:3 mimeType:mimeType requestUrl:url statusCode:404 httpVersion:httpVersion];
        }
        
        //4.响应
        [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocol:self didLoadData:data];
        [[self client] URLProtocolDidFinishLoading:self];
    }
    else {
        self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
    }
}

- (void)stopLoading
{
    if (self.connection != nil)
    {
        [self.connection cancel];
        self.connection = nil;
    }
}


- (NSString *)getMIMETypeWithCAPIAtFilePath:(NSString *)path
{
    if (![[[NSFileManager alloc] init] fileExistsAtPath:path]) {
        return nil;
    }
    
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType)
    ;
}

#pragma mark - 拼接响应Response
- (NSHTTPURLResponse *)jointResponseWithData:(NSData *)data dataLength:(NSInteger)dataLength mimeType:(NSString *)mimeType requestUrl:(NSURL *)requestUrl statusCode:(NSInteger)statusCode httpVersion:(NSString *)httpVersion
{
    NSDictionary *dict = @{@"Content-type":mimeType,
                           @"Content-length":[NSString stringWithFormat:@"%ld",dataLength]};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:requestUrl statusCode:statusCode HTTPVersion:httpVersion headerFields:dict];
    return response;
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
    NSString *tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dist"];
    NSString *fileAbsoluteURL = [@"file:/" stringByAppendingString:tmpFilePath];
    return [absoluteURL stringByReplacingOccurrencesOfString:regPrefix
                                                 withString:fileAbsoluteURL];
}

+ (NSString *)generateDateReadPath:(NSString *) absoluteURL {
    NSString *fileDataReadURL = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dist"];
    return [absoluteURL stringByReplacingOccurrencesOfString:regPrefix
                                                  withString:fileDataReadURL];
}
@end

