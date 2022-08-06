//
//  main.m
//  jsc-cli
//
//  Created by 程劭非 on 2022/8/3.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        JSContext* context = [[JSContext alloc] init];
        
        NSMutableArray * macroTaskQueue = [[NSMutableArray alloc] init];
        NSConditionLock* condLock = [[NSConditionLock alloc] initWithCondition:0];
        
        context[@"console"] = [JSValue valueWithNewObjectInContext:context];
        context[@"console"][@"log"] = ^(JSValue* s) {
            NSLog(@"%@", [s toString]);
        };
        
        context[@"setTimeout"] = ^(JSValue* f, JSValue* duration) {
            NSThread* timer = [[NSThread alloc]initWithBlock:^{
                [NSThread sleepForTimeInterval:[duration toDouble] / 1000];
                
                [condLock lock];
                
                [macroTaskQueue addObject:f];
                
                [condLock unlockWithCondition:1];
                //[f callWithArguments:@[]];
            }];
            [timer start];
        };
        
        NSThread* scanner = [[NSThread alloc]initWithBlock:^{
            char sourceCode[1024];
            while(scanf("%[^\n]", sourceCode) != -1) {
                getchar();
                [condLock lock];
                
                [macroTaskQueue addObject:[NSString stringWithUTF8String: sourceCode]];
                
                [condLock unlockWithCondition:1];
            }
        }];
        [scanner start];

        while(true) { //Event Loop
            [condLock lockWhenCondition:1];
            for (id task in macroTaskQueue){
                if([task isKindOfClass:JSValue.class])
                    [task callWithArguments:@[]];
                if([task isKindOfClass:NSString.class]) {
                    JSValue* result = [context evaluateScript:task];
                    NSLog(@"%@", [result toString]);
                }
            }
            [macroTaskQueue removeAllObjects];
            [condLock unlockWithCondition:0];
        }

    }
    return 0;
}
