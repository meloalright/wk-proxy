```
思路: 使用NSURLProtocol拦截请求转发到本地。
```
   
> 本文作者为[简书-melo的微博](https://www.jianshu.com/users/f6323e43dd6c)/[Github-meloalright](https://github.com/meloalright)，转载请注明出处哦。

## 1.确认离线化需求

```
部门负责的app有一部分使用的线上h5页，长期以来加载略慢... 

于是考虑使用离线化加载。
   
确保[低速网络]或[无网络]可网页秒开。
```

## 2.使用[NSURLProtocol]拦截  

`区别于uiwebview wkwebview使用如下方法拦截`   

```objective-c
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 区别于uiwebview wkwebview使用如下方法拦截
    Class cls = NSClassFromString(@"WKBrowsingContextController");
    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
    if ([(id)cls respondsToSelector:sel]) {
        [(id)cls performSelector:sel withObject:@"http"];
        [(id)cls performSelector:sel withObject:@"https"];
    }
}
```
```objective-c
# 注册NSURLProtocol拦截
- (IBAction)regist:(id)sender {
    [NSURLProtocol registerClass:[FilteredProtocol class]];
}
```
```objective-c
# 注销NSURLProtocol拦截
- (IBAction)unregist:(id)sender {
    [NSURLProtocol unregisterClass:[FilteredProtocol class]];
}
```

## 3.下载[zip] + 使用[SSZipArchive]解压 

`需要先 #import "SSZipArchive.h`   

```objective-c
- (void)downloadZip {
    NSDictionary *_headers;
    NSURLSession *_session = [self sessionWithHeaders:_headers];
    NSURL *url = [NSURL URLWithString: @"http://10.2.138.225:3238/dist.zip"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // 初始化cachepath
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 删除之前已有的文件
    [fm removeItemAtPath:[cachePath stringByAppendingPathComponent:@"dist.zip"] error:nil];
    
    NSURLSessionDownloadTask *downloadTask=[_session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!error) {
            
            NSError *saveError;
            
            NSURL *saveUrl = [NSURL fileURLWithPath: [cachePath stringByAppendingPathComponent:@"dist.zip"]];
            
            // location是下载后的临时保存路径,需要将它移动到需要保存的位置
            [[NSFileManager defaultManager] copyItemAtURL:location toURL:saveUrl error:&saveError];
            if (!saveError) {
                NSLog(@"task ok");
                if([SSZipArchive unzipFileAtPath:
                    [cachePath stringByAppendingPathComponent:@"dist.zip"]
                                   toDestination:cachePath]) {
                    NSLog(@"unzip ok");// 解压成功
                }
                else {
                    NSLog(@"unzip err");// 解压失败
                }
            }
            else {
                NSLog(@"task err");
            }
        }
        else {
            NSLog(@"error is :%@", error.localizedDescription);
        }
    }];
    
    [downloadTask resume];
}
```

## 4.迁移资源至[NSTemporary]  

`[wkwebview]真机不支持直接加载[NSCache]资源`    
`需要先迁移资源至[NSTemporary]`   

```objective-c
- (void)migrateDistToTempory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *cacheFilePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"dist"];
    NSString *tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dist"];
    
    // 先删除tempory已有的dist资源
    [fm removeItemAtPath:tmpFilePath error:nil];
    NSError *saveError;
    
    // 从caches拷贝dist到tempory临时文件夹
    [[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:cacheFilePath] toURL:[NSURL fileURLWithPath:tmpFilePath] error:&saveError];
    NSLog(@"Migrate dist to tempory ok");
}
```

## 5.转发请求
`如果[/static]开头 => 则转发[Request]到本地[.css/.js]资源`   
`如果[index.html]结尾 => 就直接[Load]本地[index.html] (否则[index.html]可能会加载失败)`   

```objective-c
//
//  ProtocolCustom.m
//  proxy-browser
//
//  Created by melo的微博 on 2018/4/8.
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
```
```objective-c
@implementation FilteredProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [NSURLProtocol propertyForKey:FilteredKey inRequest:request]== nil;
}
```
```objective-c
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
```
```objective-c
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}
```
```objective-c
# 如果[index.html]结尾 => 就直接[Load]本地[index.html]
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
```
```objective-c
- (void)stopLoading
{
    if (self.connection != nil)
    {
        [self.connection cancel];
        self.connection = nil;
    }
}
```
```objective-c
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
    return (__bridge NSString *)(MIMEType);
}
```
```objective-c
#pragma mark - 拼接响应Response
- (NSHTTPURLResponse *)jointResponseWithData:(NSData *)data dataLength:(NSInteger)dataLength mimeType:(NSString *)mimeType requestUrl:(NSURL *)requestUrl statusCode:(NSInteger)statusCode httpVersion:(NSString *)httpVersion
{
    NSDictionary *dict = @{@"Content-type":mimeType,
                           @"Content-length":[NSString stringWithFormat:@"%ld",dataLength]};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:requestUrl statusCode:statusCode HTTPVersion:httpVersion headerFields:dict];
    return response;
}
```
```objective-c
#pragma mark- NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}
```
```objective-c
#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseData = [[NSMutableData alloc] init];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}
```
```objective-c
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}
```
```objective-c
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}
```
```objective-c
+ (NSString *)generateProxyPath:(NSString *) absoluteURL {
    NSString *tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dist"];
    NSString *fileAbsoluteURL = [@"file:/" stringByAppendingString:tmpFilePath];
    return [absoluteURL stringByReplacingOccurrencesOfString:regPrefix
                                                 withString:fileAbsoluteURL];
}
```
```objective-c
+ (NSString *)generateDateReadPath:(NSString *) absoluteURL {
    NSString *fileDataReadURL = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dist"];
    return [absoluteURL stringByReplacingOccurrencesOfString:regPrefix
                                                  withString:fileDataReadURL];
}
@end
```


## 结语:


> 完整[DEMO]请参考: [https://github.com/meloalright/wk-proxy](https://github.com/meloalright/wk-proxy)  
(∩_∩)求给个☆哦

   

## 鸣谢:

> 参考文档:   
[1.简书: iOS UIWebView小整理（三）(利用NSURLProtocol加载本地js、css资源)](https://www.jianshu.com/p/731f49e74742)      
[2.Github: Yeatse/NSURLProtocol-WebKitSupport](https://github.com/yeatse/NSURLProtocol-WebKitSupport)   
[3.简书: 获得文件的MIME Type](https://www.jianshu.com/p/2ae55d0618d9)
