#import <Foundation/Foundation.h>
#import <os/log.h>

NS_ASSUME_NONNULL_BEGIN

extern os_log_t IPLog(void);

#define IPInfo(fmt, ...)   os_log(IPLog(), "[iprox] " fmt, ##__VA_ARGS__)
#define IPDebug(fmt, ...)  os_log_debug(IPLog(), "[iprox] " fmt, ##__VA_ARGS__)
#define IPError(fmt, ...)  os_log_error(IPLog(), "[iprox] " fmt, ##__VA_ARGS__)

NS_ASSUME_NONNULL_END
