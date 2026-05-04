#pragma once

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#ifdef __cplusplus
#import <DeckLinkAPI.h>
#endif

NS_INLINE NSString * _Nonnull DLABErrorDomain(void)
{
    return @"com.MyCometG3.DLABridging.ErrorDomain";
}

NS_INLINE NSString * _Nonnull DLABFunctionLineDescription(const char * _Nonnull functionName, int line)
{
    return [NSString stringWithFormat:@"%s (%d)", functionName, line];
}

NS_INLINE BOOL DLABAssignError(NSError * _Nullable * _Nullable error,
                               NSString * _Nullable description,
                               NSString * _Nullable failureReason,
                               NSInteger code)
{
    if (error) {
        if (!description) description = @"unknown description";
        if (!failureReason) failureReason = @"unknown failureReason";
        
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description,
                                   NSLocalizedFailureReasonErrorKey : failureReason,};
        *error = [NSError errorWithDomain:DLABErrorDomain() code:code userInfo:userInfo];
        return YES;
    }
    return NO;
}

NS_INLINE void DLABRaiseUnavailableInit(id _Nonnull selfObject, SEL _Nonnull requiredSelector)
{
    NSString *classString = NSStringFromClass([selfObject class]);
    NSString *selectorString = NSStringFromSelector(requiredSelector);
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[[%@ alloc] %@] instead", classString, selectorString];
}

NS_INLINE void DLABRaiseUnavailableSingletonInit(id _Nonnull selfObject, NSString * _Nonnull replacementText)
{
    NSString *classString = NSStringFromClass([selfObject class]);
    [NSException raise:NSGenericException
                format:@"Disabled. Use +[%@ %@] instead", classString, replacementText];
}

NS_INLINE void DLABDispatchSyncIfNeeded(dispatch_queue_t _Nullable queue, void * _Nullable key, dispatch_block_t _Nonnull block)
{
    if (queue) {
        if (key && dispatch_get_specific(key)) {
            block();
        } else {
            dispatch_sync(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

NS_INLINE void DLABDispatchAsyncIfNeeded(dispatch_queue_t _Nullable queue, void * _Nullable key, dispatch_block_t _Nonnull block)
{
    if (queue) {
        if (key && dispatch_get_specific(key)) {
            block();
        } else {
            dispatch_async(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

#ifdef __cplusplus
template <typename Interface, typename KeyType>
NS_INLINE NSNumber * _Nullable DLABGetFlagValue(Interface * _Nonnull iface,
                                                KeyType key,
                                                NSError * _Nullable * _Nullable error,
                                                const char * _Nonnull functionName,
                                                int lineNumber,
                                                NSString * _Nullable failureReason)
{
    bool newValue = false;
    HRESULT result = iface->GetFlag(key, &newValue);
    if (result == S_OK) {
        return @(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSNumber * _Nullable DLABGetIntValue(Interface * _Nonnull iface,
                                               KeyType key,
                                               NSError * _Nullable * _Nullable error,
                                               const char * _Nonnull functionName,
                                               int lineNumber,
                                               NSString * _Nullable failureReason)
{
    int64_t newValue = 0;
    HRESULT result = iface->GetInt(key, &newValue);
    if (result == S_OK) {
        return @(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSNumber * _Nullable DLABGetFloatValue(Interface * _Nonnull iface,
                                                 KeyType key,
                                                 NSError * _Nullable * _Nullable error,
                                                 const char * _Nonnull functionName,
                                                 int lineNumber,
                                                 NSString * _Nullable failureReason)
{
    double newValue = 0;
    HRESULT result = iface->GetFloat(key, &newValue);
    if (result == S_OK) {
        return @(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSString * _Nullable DLABGetStringValue(Interface * _Nonnull iface,
                                                  KeyType key,
                                                  NSError * _Nullable * _Nullable error,
                                                  const char * _Nonnull functionName,
                                                  int lineNumber,
                                                  NSString * _Nullable failureReason)
{
    CFStringRef newValue = NULL;
    HRESULT result = iface->GetString(key, &newValue);
    if (result == S_OK) {
        return (NSString *)CFBridgingRelease(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSNumber * _Nullable DLABGetFlagWithParam(Interface * _Nonnull iface,
                                                    KeyType key,
                                                    uint64_t param,
                                                    NSError * _Nullable * _Nullable error,
                                                    const char * _Nonnull functionName,
                                                    int lineNumber,
                                                    NSString * _Nullable failureReason)
{
    bool newValue = false;
    HRESULT result = iface->GetFlagWithParam(key, param, &newValue);
    if (result == S_OK) {
        return @(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSNumber * _Nullable DLABGetIntWithParam(Interface * _Nonnull iface,
                                                   KeyType key,
                                                   uint64_t param,
                                                   NSError * _Nullable * _Nullable error,
                                                   const char * _Nonnull functionName,
                                                   int lineNumber,
                                                   NSString * _Nullable failureReason)
{
    int64_t newValue = 0;
    HRESULT result = iface->GetIntWithParam(key, param, &newValue);
    if (result == S_OK) {
        return @(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSNumber * _Nullable DLABGetFloatWithParam(Interface * _Nonnull iface,
                                                     KeyType key,
                                                     uint64_t param,
                                                     NSError * _Nullable * _Nullable error,
                                                     const char * _Nonnull functionName,
                                                     int lineNumber,
                                                     NSString * _Nullable failureReason)
{
    double newValue = 0;
    HRESULT result = iface->GetFloatWithParam(key, param, &newValue);
    if (result == S_OK) {
        return @(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE NSString * _Nullable DLABGetStringWithParam(Interface * _Nonnull iface,
                                                      KeyType key,
                                                      uint64_t param,
                                                      NSError * _Nullable * _Nullable error,
                                                      const char * _Nonnull functionName,
                                                      int lineNumber,
                                                      NSString * _Nullable failureReason)
{
    CFStringRef newValue = NULL;
    HRESULT result = iface->GetStringWithParam(key, param, &newValue);
    if (result == S_OK) {
        return (NSString *)CFBridgingRelease(newValue);
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return nil;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetFlagValue(Interface * _Nonnull iface,
                                KeyType key,
                                bool value,
                                NSError * _Nullable * _Nullable error,
                                const char * _Nonnull functionName,
                                int lineNumber,
                                NSString * _Nullable failureReason)
{
    HRESULT result = iface->SetFlag(key, value);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetIntValue(Interface * _Nonnull iface,
                               KeyType key,
                               int64_t value,
                               NSError * _Nullable * _Nullable error,
                               const char * _Nonnull functionName,
                               int lineNumber,
                               NSString * _Nullable failureReason)
{
    HRESULT result = iface->SetInt(key, value);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetFloatValue(Interface * _Nonnull iface,
                                 KeyType key,
                                 double value,
                                 NSError * _Nullable * _Nullable error,
                                 const char * _Nonnull functionName,
                                 int lineNumber,
                                 NSString * _Nullable failureReason)
{
    HRESULT result = iface->SetFloat(key, value);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetStringValue(Interface * _Nonnull iface,
                                  KeyType key,
                                  NSString * _Nonnull value,
                                  NSError * _Nullable * _Nullable error,
                                  const char * _Nonnull functionName,
                                  int lineNumber,
                                  NSString * _Nullable failureReason)
{
    CFStringRef newValue = (CFStringRef)CFBridgingRetain(value);
    HRESULT result = iface->SetString(key, newValue);
    CFRelease(newValue);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetFlagWithParam(Interface * _Nonnull iface,
                                    KeyType key,
                                    uint64_t param,
                                    bool value,
                                    NSError * _Nullable * _Nullable error,
                                    const char * _Nonnull functionName,
                                    int lineNumber,
                                    NSString * _Nullable failureReason)
{
    HRESULT result = iface->SetFlagWithParam(key, param, value);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetIntWithParam(Interface * _Nonnull iface,
                                   KeyType key,
                                   uint64_t param,
                                   int64_t value,
                                   NSError * _Nullable * _Nullable error,
                                   const char * _Nonnull functionName,
                                   int lineNumber,
                                   NSString * _Nullable failureReason)
{
    HRESULT result = iface->SetIntWithParam(key, param, value);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetFloatWithParam(Interface * _Nonnull iface,
                                     KeyType key,
                                     uint64_t param,
                                     double value,
                                     NSError * _Nullable * _Nullable error,
                                     const char * _Nonnull functionName,
                                     int lineNumber,
                                     NSString * _Nullable failureReason)
{
    HRESULT result = iface->SetFloatWithParam(key, param, value);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}

template <typename Interface, typename KeyType>
NS_INLINE BOOL DLABSetStringWithParam(Interface * _Nonnull iface,
                                      KeyType key,
                                      uint64_t param,
                                      NSString * _Nonnull value,
                                      NSError * _Nullable * _Nullable error,
                                      const char * _Nonnull functionName,
                                      int lineNumber,
                                      NSString * _Nullable failureReason)
{
    CFStringRef newValue = (CFStringRef)CFBridgingRetain(value);
    HRESULT result = iface->SetStringWithParam(key, param, newValue);
    CFRelease(newValue);
    if (result == S_OK) {
        return YES;
    }
    
    DLABAssignError(error,
                    DLABFunctionLineDescription(functionName, lineNumber),
                    failureReason,
                    (NSInteger)result);
    return NO;
}
#endif
