#if defined _ccl_proc_included
 #endinput
#endif
#define _ccl_proc_included

/* Prototype properties of the client message */
/* const char[] szBind = {TEAM}, {NAME}, {MSG}, {STATUS} */
forward void ccl_proc_RebuildString(int iClient, const char[] szBind, char[] szBuffer, int iSize);

/* Message sended to client (non rcon say "msg") */
forward bool ccl_proc_OnServerMsg(char[] szMessage, int MsgLen);

forward void ccl_config_parsed();

native ArrayList ccl_drop_triggers();
native void ccl_clear_allcolors(char[] szBuffer, int iSize);

public SharedPlugin __pl_ccl_proc= 
{
	name = "ccl_proc",
	file = "ccl_proc.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ccl_proc_SetNTVOptional()
{
	MarkNativeAsOptional("ccl_drop_triggers");
	MarkNativeAsOptional("ccl_clear_allcolors");
}
#endif