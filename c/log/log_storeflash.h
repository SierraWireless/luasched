#ifndef LOGSTOREFLASH_H_
#define LOGSTOREFLASH_H_

#include "lua.h"

int l_logflashinit(lua_State* L);
int l_logflashstore(lua_State* L);
int l_logflashgetsource(lua_State* L);
int l_logflashdebug(lua_State* L);

#endif /* LOGSTOREFLASH_H_ */
