
#ifndef ACTIONS_H_
#define ACTIONS_H_

#include "mem_define.h"

#include "teel_internal.h"

TeelCmd tl_act_backspace(TeelInstance* ti);
TeelCmd tl_act_deleteprevword(TeelInstance* ti);
TeelCmd tl_act_delete(TeelInstance* ti);
TeelCmd tl_act_deletenextword(TeelInstance* ti);
TeelCmd tl_act_editdone(TeelInstance* ti);
TeelCmd tl_act_linebreak(TeelInstance* ti);
TeelCmd tl_act_moveleft(TeelInstance* ti);
TeelCmd tl_act_moveright(TeelInstance* ti);
TeelCmd tl_act_movetostartpos(TeelInstance* ti);
TeelCmd tl_act_movetoendpos(TeelInstance* ti);
TeelCmd tl_act_movetoprevword(TeelInstance* ti);
TeelCmd tl_act_movetonextword(TeelInstance* ti);
TeelCmd tl_act_exit(TeelInstance* ti);
TeelCmd tl_act_overwriteinserttoggle(TeelInstance* ti);
TeelCmd tl_act_susp(TeelInstance* ti);
TeelCmd tl_act_ip(TeelInstance* ti);
TeelCmd tl_act_eof(TeelInstance* ti);
TeelCmd tl_act_historypreventry(TeelInstance* ti);
TeelCmd tl_act_historynextentry(TeelInstance* ti);
TeelCmd tl_act_autocomplete(TeelInstance* ti);



TeelCmd tl_act_debugF11(TeelInstance* ti);
TeelCmd tl_act_debugF12(TeelInstance* ti);
TeelCmd tl_act_testabcstring(TeelInstance* ti);
TeelCmd tl_act_test012string(TeelInstance* ti);

#endif /* ACTIONS_H_ */
