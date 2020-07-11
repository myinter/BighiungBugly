//
//  BighiungBugly.h
//  BighiungBugly
//
//  Created by bighiung on 2020/7/11.
//  Copyright © 2020 bighiung. All rights reserved.
//

#import <Foundation/Foundation.h>




//用于注册接收发生错误的调用栈信息
@class BighiungBugly;

//用于注册的发生异常的handler，可以在这里进行异常上报。
typedef void(^BighiungExceptionBlockHandler)(NSArray<BighiungBugly *> * _Nullable backtrace,NSString * _Nonnull threadName);
typedef void BighiungExceptionHandler(NSArray<BighiungBugly *> * _Nullable backtrace,NSString * _Nonnull threadName);
void setExceptionHandler(BighiungExceptionHandler * _Nullable handler);
void setExceptionBlockHandler(BighiungExceptionBlockHandler _Nullable handler);

//获取当前线程的调用栈信息
NSArray<BighiungBugly *> * _Nullable BacktraceInfoOfCurrentThread(void);
//获取某个线程的调用栈信息,若传空，则返回当前线程
NSArray<BighiungBugly *> * _Nullable BacktraceInfoOfNSThread(NSThread * _Nullable thread);
//发生异常时，将完整的调用栈信息输出。

NS_ASSUME_NONNULL_BEGIN
//libdyld.dylib                   0x10ea9c92d start + 1
@interface BighiungBugly : NSObject
@property (nonatomic,copy) NSString *imageName; //  包/镜像名
@property (nonatomic,copy) NSString *address; // 函数地址
@property (nonatomic,copy) NSString *functionName; // 函数 or 方法名
@property (nonatomic,copy) NSNumber *offset; // 是函数中执行到的指令相对于函数开头的偏移量
@property (nonatomic,copy) NSString *descriptionText; // 调用栈中某一个元素的表示字符串
@end

NS_ASSUME_NONNULL_END
