//
//  BighiungBugly.m
//  BighiungBugly
//
//  Created by bighiung on 2020/7/11.
//  Copyright © 2020 bighiung. All rights reserved.
//

#import "BighiungBugly.h"
#import <mach/mach.h>
#include <dlfcn.h>
#include <pthread.h>
#include <sys/types.h>
#include <limits.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#import "fishhook.h"

#if defined(__LP64__)
#define TRACE_FMT         "%-4d%-31s 0x%016lx %s + %lu"
#define POINTER_FMT       "0x%016lx"
#define POINTER_SHORT_FMT "0x%lx"
#define NLIST struct nlist_64
#else
#define TRACE_FMT         "%-4d%-31s 0x%08lx %s + %lu"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#define NLIST struct nlist
#endif


#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

#pragma -mark DEFINE MACRO FOR DIFFERENT CPU ARCHITECTURE
#if defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#define THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define THREAD_STATE ARM_THREAD_STATE64
#define FRAME_POINTER __fp
#define STACK_POINTER __sp
#define INSTRUCTION_ADDRESS __pc

#elif defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#define THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define THREAD_STATE ARM_THREAD_STATE
#define FRAME_POINTER __r[7]
#define STACK_POINTER __sp
#define INSTRUCTION_ADDRESS __pc

#elif defined(__x86_64__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define THREAD_STATE x86_THREAD_STATE64
#define FRAME_POINTER __rbp
#define STACK_POINTER __rsp
#define INSTRUCTION_ADDRESS __rip

#elif defined(__i386__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define THREAD_STATE x86_THREAD_STATE32
#define FRAME_POINTER __ebp
#define STACK_POINTER __esp
#define INSTRUCTION_ADDRESS __eip

#endif

BighiungExceptionHandler *handlerForNSExceptionAndMachSignal = NULL;
BighiungExceptionBlockHandler blockForNSExceptionAndMachSignal = NULL;


NSArray<BighiungBugly *> *BacktraceInfoOfCurrentThread();
typedef struct StackFrame{
    const struct StackFrame *const previous;
    const uintptr_t return_address;
} StackFrame;

static mach_port_t main_thread_id;
void RegisterSignalHandler(void);
void HandleException(NSException *exception);

@implementation BighiungBugly

static int (*orig_NSSetUncaughtExceptionHandler)(NSUncaughtExceptionHandler * _Nullable) = NULL;

void Bugly_NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * _Nullable handler){
    //阻止Bugly以外的代码注册ExceptionHandler
    
    NSArray<NSNumber *> *returnAddresses = [NSThread callStackReturnAddresses];
    
    BOOL isFromBugly = NO;
    for (NSNumber *address in returnAddresses) {
        void (*addressValue)(void) = (void (*)(void))[address pointerValue];
        if (addressValue > ((void (*)(void))registerExceptionHandler) && addressValue < guardNullFunc) {
            //返回地址位于 registerExceptionHandler 和 guardNullFunc 之间，表明来自 bugly的注册
            isFromBugly = YES;
            break;
        }
    }
    if (isFromBugly) {
        //调用真实的 NSSetUncaughtExceptionHandler
        orig_NSSetUncaughtExceptionHandler(handler);
    }
}
+(void)load
{
    registerExceptionHandler();
}

void registerExceptionHandler()
{
    //记录下主线程的id
    main_thread_id = mach_thread_self();
    RegisterSignalHandler();
    [[NSThread currentThread]setName:@"main thread"];
    //hook NSSetUncaughtExceptionHandler 方法，避免其他模块注册侦听干扰bugly
    rebind_symbols((struct rebinding[1]){{"NSSetUncaughtExceptionHandler", Bugly_NSSetUncaughtExceptionHandler, (void *)&orig_NSSetUncaughtExceptionHandler}}, 1);
    NSSetUncaughtExceptionHandler(HandleException);
}

void guardNullFunc(){
    
}

@end

void HandleException(NSException *exception) {
    if (handlerForNSExceptionAndMachSignal || blockForNSExceptionAndMachSignal) {
        NSArray<BighiungBugly *> *buglies = BacktraceInfoOfCurrentThread();
        NSString *threadName = [NSThread currentThread].name;
        if (handlerForNSExceptionAndMachSignal) {
            handlerForNSExceptionAndMachSignal(buglies,threadName);
        }
        if (blockForNSExceptionAndMachSignal) {
            blockForNSExceptionAndMachSignal(buglies,threadName);
        }
    }
}

void SignalHandler(int signal) {
    if (handlerForNSExceptionAndMachSignal || blockForNSExceptionAndMachSignal) {
        //获取当前线程的调用栈信息，并上报。
        NSArray<BighiungBugly *> *buglies = BacktraceInfoOfCurrentThread();
        NSString *threadName = [NSThread currentThread].name;
        if (handlerForNSExceptionAndMachSignal) {
            handlerForNSExceptionAndMachSignal(buglies,threadName);
        }
        if (blockForNSExceptionAndMachSignal) {
            blockForNSExceptionAndMachSignal(buglies,threadName);
        }
    }
}

void RegisterSignalHandler(void) {
    signal(SIGHUP, SignalHandler);
    signal(SIGINT, SignalHandler);
    signal(SIGQUIT, SignalHandler);
    signal(SIGABRT, SignalHandler);
    signal(SIGILL, SignalHandler);
    signal(SIGSEGV, SignalHandler);
    signal(SIGFPE, SignalHandler);
    signal(SIGBUS, SignalHandler);
    signal(SIGPIPE, SignalHandler);
}

void setExceptionHandler(BighiungExceptionHandler *handler)
{
    handlerForNSExceptionAndMachSignal = handler;
}

void setExceptionBlockHandler(BighiungExceptionBlockHandler _Nullable handler)
{
    blockForNSExceptionAndMachSignal = handler;
}

uintptr_t Mach_framePointer(mcontext_t const machineContext){
    return machineContext->__ss.FRAME_POINTER;
}

//获取某一个线程的状态
bool FillThreadStateIntoMachineContext(thread_t thread, _STRUCT_MCONTEXT *machineContext) {
    mach_msg_type_number_t state_count = THREAD_STATE_COUNT;
    kern_return_t kr = thread_get_state(thread, THREAD_STATE, (thread_state_t)&machineContext->__ss, &state_count);
    return (kr == KERN_SUCCESS);
}

uintptr_t Mach_instructionAddress(mcontext_t const machineContext){
    return machineContext->__ss.INSTRUCTION_ADDRESS;
}

uintptr_t Mach_linkRegister(mcontext_t const machineContext){
#if defined(__i386__) || defined(__x86_64__)
    return 0;
#else
    return machineContext->__ss.__lr;
#endif
}

kern_return_t Mach_copyMem(const void *const src, void *const dst, const size_t numBytes){
    vm_size_t bytesCopied = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}

uintptr_t FirstCmdAfterHeader(const struct mach_header* const header) {
    switch(header->magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((struct mach_header_64*)header) + 1);
        default:
            return 0;  // Header is corrupt
    }
}


uint32_t ImageIndexContainingAddress(const uintptr_t address) {
    const uint32_t imageCount = _dyld_image_count();
    const struct mach_header* header = 0;
    
    for(uint32_t iImg = 0; iImg < imageCount; iImg++) {
        header = _dyld_get_image_header(iImg);
        if(header != NULL) {
            // Look for a segment command with this address within its range.
            uintptr_t addressWSlide = address - (uintptr_t)_dyld_get_image_vmaddr_slide(iImg);
            uintptr_t cmdPtr = FirstCmdAfterHeader(header);
            if(cmdPtr == 0) {
                continue;
            }
            for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
                const struct load_command* loadCmd = (struct load_command*)cmdPtr;
                if(loadCmd->cmd == LC_SEGMENT) {
                    const struct segment_command* segCmd = (struct segment_command*)cmdPtr;
                    if(addressWSlide >= segCmd->vmaddr &&
                       addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                else if(loadCmd->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64* segCmd = (struct segment_command_64*)cmdPtr;
                    if(addressWSlide >= segCmd->vmaddr &&
                       addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        return iImg;
                    }
                }
                cmdPtr += loadCmd->cmdsize;
            }
        }
    }
    return UINT_MAX;
}

uintptr_t SegmentBaseOfImageIndex(const uint32_t idx) {
    const struct mach_header* header = _dyld_get_image_header(idx);
    
    // Look for a segment command and return the file image address.
    uintptr_t cmdPtr = FirstCmdAfterHeader(header);
    if(cmdPtr == 0) {
        return 0;
    }
    for(uint32_t i = 0;i < header->ncmds; i++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        if(loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command* segmentCmd = (struct segment_command*)cmdPtr;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return segmentCmd->vmaddr - segmentCmd->fileoff;
            }
        }
        else if(loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64* segmentCmd = (struct segment_command_64*)cmdPtr;
            if(strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return 0;
}



bool Dladdr(const uintptr_t address, Dl_info* const info) {
    info->dli_fname = NULL;
    info->dli_fbase = NULL;
    info->dli_sname = NULL;
    info->dli_saddr = NULL;
    
    const uint32_t idx = ImageIndexContainingAddress(address);
    if(idx == UINT_MAX) {
        return false;
    }
    const struct mach_header* header = _dyld_get_image_header(idx);
    const uintptr_t imageVMAddrSlide = (uintptr_t)_dyld_get_image_vmaddr_slide(idx);
    const uintptr_t addressWithSlide = address - imageVMAddrSlide;
    const uintptr_t segmentBase = SegmentBaseOfImageIndex(idx) + imageVMAddrSlide;
    if(segmentBase == 0) {
        return false;
    }
    
    info->dli_fname = _dyld_get_image_name(idx);
    info->dli_fbase = (void*)header;
    
    // Find symbol tables and get whichever symbol is closest to the address.
    const NLIST* bestMatch = NULL;
    uintptr_t bestDistance = ULONG_MAX;
    uintptr_t cmdPtr = FirstCmdAfterHeader(header);
    if(cmdPtr == 0) {
        return false;
    }
    for(uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command* loadCmd = (struct load_command*)cmdPtr;
        if(loadCmd->cmd == LC_SYMTAB) {
            const struct symtab_command* symtabCmd = (struct symtab_command*)cmdPtr;
            const NLIST* symbolTable = (NLIST*)(segmentBase + symtabCmd->symoff);
            const uintptr_t stringTable = segmentBase + symtabCmd->stroff;
            for(uint32_t iSym = 0; iSym < symtabCmd->nsyms; iSym++) {
                // If n_value is 0, the symbol refers to an external object.
                if(symbolTable[iSym].n_value != 0) {
                    uintptr_t symbolBase = symbolTable[iSym].n_value;
                    uintptr_t currentDistance = addressWithSlide - symbolBase;
                    if((addressWithSlide >= symbolBase) &&
                       (currentDistance <= bestDistance)) {
                        bestMatch = symbolTable + iSym;
                        bestDistance = currentDistance;
                    }
                }
            }
            if(bestMatch != NULL) {
                info->dli_saddr = (void*)(bestMatch->n_value + imageVMAddrSlide);
                info->dli_sname = (char*)((intptr_t)stringTable + (intptr_t)bestMatch->n_un.n_strx);
                if(*info->dli_sname == '_') {
                    info->dli_sname++;
                }
                // This happens if all symbols have been stripped.
                if(info->dli_saddr == info->dli_fbase && bestMatch->n_type == 3) {
                    info->dli_sname = NULL;
                }
                break;
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return true;
}

//将一个栈帧符号化
void Symbolicate(const uintptr_t* const backtraceBuffer,
                    Dl_info* const symbolsBuffer,
                    const int numEntries,
                    const int skippedEntries){
    int i = 0;
    if(!skippedEntries && i < numEntries) {
        Dladdr(backtraceBuffer[i], &symbolsBuffer[i]);
        i++;
    }
    for(; i < numEntries; i++) {
        Dladdr(CALL_INSTRUCTION_FROM_RETURN_ADDRESS(backtraceBuffer[i]), &symbolsBuffer[i]);
    }
}

const char* LastPathEntry(const char* const path) {
    if(path == NULL) {
        return NULL;
    }
    
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}


BighiungBugly* BighiungBuglyFromDLInfo(
                               const uintptr_t address,
                               const Dl_info* const dlInfo) {
    char faddrBuff[20];
    char saddrBuff[20];
    
    //fname 是 包/镜像名
    //sname 是 函数/方法名
    //address 是 函数的地址
    //offset 是函数中执行到的指令相对于函数开头的偏移量
    const char* fname = LastPathEntry(dlInfo->dli_fname);
    if(fname == NULL) {
        sprintf(faddrBuff, POINTER_FMT, (uintptr_t)dlInfo->dli_fbase);
        fname = faddrBuff;
    }
        uintptr_t offset = address - (uintptr_t)dlInfo->dli_saddr;
    const char* sname = dlInfo->dli_sname;
    if(sname == NULL) {
        sprintf(saddrBuff, POINTER_SHORT_FMT, (uintptr_t)dlInfo->dli_fbase);
        sname = saddrBuff;
        offset = address - (uintptr_t)dlInfo->dli_fbase;
    }
    BighiungBugly *bugly = [BighiungBugly new];
    bugly.imageName = [NSString stringWithFormat:@"%s",fname];
    bugly.address = address;

    bugly.functionName = [NSString stringWithFormat:@"%s",sname];
    bugly.offset = @(offset);
    
#if __LP64__ || 0 || NS_BUILD_32_LIKE_64
    bugly.descriptionText = [NSString stringWithFormat:@"%-30s  0x%016" PRIxPTR " %s + %lu\n" ,fname, (uintptr_t)address, sname, offset];
#else
    bugly.descriptionText = [NSString stringWithFormat:@"%-30s  0x%08" PRIxPTR " %s + %lu\n" ,fname, (uintptr_t)address, sname, offset];
#endif

    return bugly;
}

NSString* bs_logBacktraceEntry(const int entryNum,
                               const uintptr_t address,
                               const Dl_info* const dlInfo) {
    char faddrBuff[20];
    char saddrBuff[20];
    
    const char* fname = LastPathEntry(dlInfo->dli_fname);
    if(fname == NULL) {
        sprintf(faddrBuff, POINTER_FMT, (uintptr_t)dlInfo->dli_fbase);
        fname = faddrBuff;
    }
    
    uintptr_t offset = address - (uintptr_t)dlInfo->dli_saddr;
    const char* sname = dlInfo->dli_sname;
    if(sname == NULL) {
        sprintf(saddrBuff, POINTER_SHORT_FMT, (uintptr_t)dlInfo->dli_fbase);
        sname = saddrBuff;
        offset = address - (uintptr_t)dlInfo->dli_fbase;
    }
    return [NSString stringWithFormat:@"%-30s  0x%08" PRIxPTR " %s + %lu\n" ,fname, (uintptr_t)address, sname, offset];
}

thread_t MachThreadFromNSThread(NSThread *nsthread) {
    if ([nsthread isMainThread]) {
        //主线程直接返回运行时初始化时记录下的id
        return (thread_t)main_thread_id;
    }
    char name[256];
    //获取当前所有线程的信息
    mach_msg_type_number_t count;
    thread_act_array_t list;
    task_threads(mach_task_self(), &list, &count);
    
    CFTimeInterval currentTimestamp = CFAbsoluteTimeGetCurrent();
    //将当前线程加上时间戳换个名字。
    NSString *originName = [nsthread name];
    [nsthread setName:[NSString stringWithFormat:@"%f", currentTimestamp]];
    
    const char *threadNameCString = [nsthread name].UTF8String;
    for (int i = 0; i < count; ++i) {
        pthread_t pt = pthread_from_mach_thread_np(list[i]);
        if (pt) {
            name[0] = '\0';
            pthread_getname_np(pt, name, sizeof name);
            if (!strcmp(name, threadNameCString)) {
                [nsthread setName:originName];
                return list[i];
            }
        }
    }
    //恢复当前线程原有的名字
    [nsthread setName:originName];
    //返回当前线程的id做个兜底
    return mach_thread_self();
}
NSArray<BighiungBugly *> *BacktraceInfoOfThread(thread_t thread);

//获取当前线程当前的调用栈信息
NSArray<BighiungBugly *> *BacktraceInfoOfCurrentThread() {
    return BacktraceInfoOfThread(mach_thread_self());
}

NSArray<BighiungBugly *> *BacktraceInfoOfThread(thread_t thread) {
    uintptr_t backtraceBuffer[50];
    int i = 0;
    _STRUCT_MCONTEXT machineContext;
    if(!FillThreadStateIntoMachineContext(thread, &machineContext)) {
        [NSException raise:@"Fail to get information about " format:@"thread: %u",thread];
    }
    
    //获取指令地址
    const uintptr_t instructionAddress = Mach_instructionAddress(&machineContext);
    backtraceBuffer[i] = instructionAddress;
    ++i;
    
    uintptr_t linkRegister = Mach_linkRegister(&machineContext);
    if (linkRegister) {
        backtraceBuffer[i] = linkRegister;
        i++;
    }
    
    if(instructionAddress == 0) {
        [NSException raise:@"Fail to get instruction address " format:@"thread: %u",thread];
    }
    
    //获取最近的栈帧，从指令地址开始获取栈帧
    StackFrame frame = {0};
    const uintptr_t framePtr = Mach_framePointer(&machineContext);
    if(framePtr == 0 ||
       Mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS) {
        [NSException raise:@"Fail to get frame pointer / 未能成功获取栈帧 " format:@"thread: %u",thread];
    }
    
    //沿着最近的栈帧往上回溯调用栈。。。backtraceBuffer 中填写的是调用栈中每一个函数的返回地址。
    for(; i < 50; i++) {
        backtraceBuffer[i] = frame.return_address;
        if(backtraceBuffer[i] == 0 ||
           frame.previous == 0 ||
           Mach_copyMem(frame.previous, &frame, sizeof(frame)) != KERN_SUCCESS) {
            //没有后续
            break;
        }
    }
    
    int backtraceLength = i;
    Dl_info symbolicated[backtraceLength];
    //将回溯后的调用栈信息符号化
    Symbolicate(backtraceBuffer, symbolicated, backtraceLength, 0);
    //将栈帧从上往下打印
    NSMutableArray *output = [NSMutableArray arrayWithCapacity:backtraceLength];
    for (int i = 0; i < backtraceLength; ++i) {
        [output addObject:BighiungBuglyFromDLInfo(backtraceBuffer[i], &symbolicated[i])];
    }
    return output;
}

NSArray<BighiungBugly *> *BacktraceInfoOfNSThread(NSThread *thread)
{
    return thread ? BacktraceInfoOfThread(MachThreadFromNSThread(thread)) : BacktraceInfoOfCurrentThread();
}

//NSString *BacktraceOfThread(thread_t thread) {
//    uintptr_t backtraceBuffer[50];
//    int i = 0;
//    NSMutableString *resultString = [[NSMutableString alloc] initWithFormat:@"Backtrace of Thread %u:\n", thread];
//
//    _STRUCT_MCONTEXT machineContext;
//    if(!FillThreadStateIntoMachineContext(thread, &machineContext)) {
//        return [NSString stringWithFormat:@"Fail to get information about thread: %u", thread];
//    }
//
//    //获取指令地址
//    const uintptr_t instructionAddress = Mach_instructionAddress(&machineContext);
//    backtraceBuffer[i] = instructionAddress;
//    ++i;
//
//    uintptr_t linkRegister = Mach_linkRegister(&machineContext);
//    if (linkRegister) {
//        backtraceBuffer[i] = linkRegister;
//        i++;
//    }
//
//    if(instructionAddress == 0) {
//        return @"Fail to get instruction address";
//    }
//
//    //获取最近的栈帧，从指令地址开始获取栈帧
//    StackFrame frame = {0};
//    const uintptr_t framePtr = Mach_framePointer(&machineContext);
//    if(framePtr == 0 ||
//       Mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS) {
//        return @"Fail to get frame pointer";
//    }
//
//    //沿着最近的栈帧往上回溯调用栈
//    for(; i < 50; i++) {
//        backtraceBuffer[i] = frame.return_address;
//        if(backtraceBuffer[i] == 0 ||
//           frame.previous == 0 ||
//           Mach_copyMem(frame.previous, &frame, sizeof(frame)) != KERN_SUCCESS) {
//            //没有后续
//            break;
//        }
//    }
//
//    int backtraceLength = i;
//    Dl_info symbolicated[backtraceLength];
//    //将回溯后的调用栈信息符号化
//    Symbolicate(backtraceBuffer, symbolicated, backtraceLength, 0);
//    //将栈帧从上往下打印
//    for (int i = 0; i < backtraceLength; ++i) {
//        [resultString appendFormat:@"%@", bs_logBacktraceEntry(i, backtraceBuffer[i], &symbolicated[i])];
//    }
//    [resultString appendFormat:@"\n"];
//    return resultString;
//}
