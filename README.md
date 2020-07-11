# BighiungBugly


2020-07-11 20:57:18.338527+0800 BighiungBugly[34371:38332673] threadName main thread
2020-07-11 20:57:18.338731+0800 BighiungBugly[34371:38332673]  libsystem_kernel.dylib          0x7fff51b5b25a mach_msg_trap + 10
2020-07-11 20:57:18.338875+0800 BighiungBugly[34371:38332673]  libsystem_kernel.dylib          0x7fff51b61fa7 thread_get_state + 405
2020-07-11 20:57:18.339001+0800 BighiungBugly[34371:38332673]  BighiungBugly                   0x10c3b2afa Mach_copyMem + 58
2020-07-11 20:57:18.339122+0800 BighiungBugly[34371:38332673]  BighiungBugly                   0x10c3b3cb7 BacktraceInfoOfThread + 551
2020-07-11 20:57:18.339221+0800 BighiungBugly[34371:38332673]  BighiungBugly                   0x10c3b2890 BacktraceInfoOfCurrentThread + 16
2020-07-11 20:57:18.339347+0800 BighiungBugly[34371:38332673]  BighiungBugly                   0x10c3b24d5 HandleException + 69
2020-07-11 20:57:18.339473+0800 BighiungBugly[34371:38332673]  CoreFoundation                  0x7fff23e3d36d __handleUncaughtException + 877
2020-07-11 20:57:18.339584+0800 BighiungBugly[34371:38332673]  libobjc.A.dylib                 0x7fff50ba8c05 _ZL15_objc_terminatev + 90
2020-07-11 20:57:18.339696+0800 BighiungBugly[34371:38332673]  libc++abi.dylib                 0x7fff4f9f6c87 _ZSt11__terminatePFvvE + 8
2020-07-11 20:57:18.339867+0800 BighiungBugly[34371:38332673]  libc++abi.dylib                 0x7fff4f9f6c29 _ZSt9terminatev + 41
2020-07-11 20:57:18.340245+0800 BighiungBugly[34371:38332673]  libdispatch.dylib               0x10c620ea2 _dispatch_client_callout + 28
2020-07-11 20:57:18.382740+0800 BighiungBugly[34371:38332673]  libdispatch.dylib               0x10c623da2 _dispatch_block_invoke_direct + 300
2020-07-11 20:57:18.382913+0800 BighiungBugly[34371:38332673]  FrontBoardServices              0x7fff36cf86e9 __FBSSERIALQUEUE_IS_CALLING_OUT_TO_A_BLOCK__ + 30
2020-07-11 20:57:18.383044+0800 BighiungBugly[34371:38332673]  FrontBoardServices              0x7fff36cf83d7 -[FBSSerialQueue _queue_performNextIfPossible] + 441
2020-07-11 20:57:18.383164+0800 BighiungBugly[34371:38332673]  FrontBoardServices              0x7fff36cf88e6 -[FBSSerialQueue _performNextFromRunLoopSource] + 22
2020-07-11 20:57:18.383279+0800 BighiungBugly[34371:38332673]  CoreFoundation                  0x7fff23da0d31 __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 17
2020-07-11 20:57:18.383408+0800 BighiungBugly[34371:38332673]  CoreFoundation                  0x7fff23da0c5c __CFRunLoopDoSource0 + 76
2020-07-11 20:57:18.383547+0800 BighiungBugly[34371:38332673]  CoreFoundation                  0x7fff23da048c __CFRunLoopDoSources0 + 268
2020-07-11 20:57:18.384027+0800 BighiungBugly[34371:38332673]  CoreFoundation                  0x7fff23d9b02e __CFRunLoopRun + 974
2020-07-11 20:57:18.384394+0800 BighiungBugly[34371:38332673]  CoreFoundation                  0x7fff23d9a944 CFRunLoopRunSpecific + 404
2020-07-11 20:57:18.384791+0800 BighiungBugly[34371:38332673]  GraphicsServices                0x7fff38ba6c1a GSEventRunModal + 139
2020-07-11 20:57:18.385180+0800 BighiungBugly[34371:38332673]  UIKitCore                       0x7fff48c8b9ec UIApplicationMain + 1605
2020-07-11 20:57:18.385502+0800 BighiungBugly[34371:38332673]  BighiungBugly                   0x10c3b2092 main + 114
2020-07-11 20:57:18.385820+0800 BighiungBugly[34371:38332673]  libdyld.dylib                   0x7fff51a231fd start + 1

Tool for statistics of crash and exceptions.
