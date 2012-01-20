#ifndef CHECKS_H
#define CHECKS_H

#include "lua.h"

#ifndef CHECKS_API
#define CHECKS_API extern
#endif


CHECKS_API int luaopen_checks( lua_State *L);

#endif

