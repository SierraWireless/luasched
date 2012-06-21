/*
 * lposixsignal.h
 *
 *  Created on: 21 fev 2012
 *      Author: Gilles
 */

#ifndef __LPOSIXSIGNAL_H__
#define __LPOSIXSIGNAL_H__

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int luaopen_sched_posixsignal(lua_State* L);

#endif /*__LPOSIXSIGNAL_H__*/
