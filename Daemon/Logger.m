#import "Logger.h"

os_log_t IPLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("com.iprox.scand", "core");
    });
    return log;
}
