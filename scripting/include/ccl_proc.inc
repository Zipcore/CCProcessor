#if defined _ccl_proc_included
 #endinput
#endif
#define _ccl_proc_included

/* Prototype properties of the client message */
/* const char[] szBind = {TEAM}, {NAME}, {MSG}, {STATUS} */
forward void ccl_proc_RebuildString(int iClient, const char[] szBind, char[] szBuffer, int iSize);

/* Message sended to client (non rcon say "msg") */
forward void ccl_proc_OnServerMsg(char[] szMessage, int MsgLen);

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
	
}
#endif