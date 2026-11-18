#ifndef BIG_DUCK_CORE_BRIDGE_H
#define BIG_DUCK_CORE_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void *bigduck_start(const char *db_path_ptr);
int32_t bigduck_send_command(void *runtime, const char *cmd_json_ptr);
char *bigduck_poll_event(void *runtime);
void bigduck_free_string(char *ptr);
void bigduck_stop(void *runtime);

#ifdef __cplusplus
}
#endif

#endif /* BIG_DUCK_CORE_BRIDGE_H */
