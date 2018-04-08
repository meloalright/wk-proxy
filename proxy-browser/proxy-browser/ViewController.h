//
//  ViewController.h
//  proxy-browser
//
//  Created by melo的苹果本 on 2018/4/8.
//  Copyright © 2018年 com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface ViewController : UIViewController
@property (strong, nonatomic) IBOutlet UIButton *browserButton;
@property (strong, nonatomic) IBOutlet UIButton *registButton;
@property (strong, nonatomic) IBOutlet UIButton *unregistButton;

@property (strong, nonatomic) IBOutlet WKWebView *wk;

@end

