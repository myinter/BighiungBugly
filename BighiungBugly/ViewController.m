//
//  ViewController.m
//  BighiungBugly
//
//  Created by bighiung on 2020/7/11.
//  Copyright © 2020 bighiung. All rights reserved.
//

#import "ViewController.h"
#import "BighiungBugly.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    setExceptionBlockHandler(^(NSArray<BighiungBugly *> * _Nullable backtrace, NSString * _Nonnull threadName) {
        NSLog(@"threadName %@ \n",threadName);
        for (BighiungBugly *bugly in backtrace) {
            NSLog(@" %@ \n",bugly.descriptionText);
        }
    });
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        //模拟异常内存地址访问
//    });
    
    [NSException raise:@"Fail to get information about " format:@"thread"];

}


@end
