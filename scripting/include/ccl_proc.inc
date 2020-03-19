#if defined _ccl_proc_included
 #endinput
#endif
#define _ccl_proc_included


/* 
	Skip color keys in a client message? 
	Calling before ccl_proc_RebuildString()
*/
forward bool ccl_proc_SkipColorsInMsg(int iClient);

/* 
	Prototype properties of the client message
	const char[] szBind = {TEAM}, {NAME}, {MSG}, {STATUS}
*/
forward void ccl_proc_RebuildString(int iClient, const char[] szBind, char[] szBuffer, int iSize);

/* Message sended by server */
forward bool ccl_proc_OnServerMsg(char[] szMessage, int MsgLen);

/* On config parsed success */
forward void ccl_config_parsed();

/* 
	Called when sending a message about changing the player's nickname 
	@ return 	Plugin_Continue - send msg / Plugin_Handle - otherwise 
*/
forward Action ccl_proc_OnUsernameChangedMsg();

native ArrayList ccl_drop_list(bool IsTriggers);

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
	MarkNativeAsOptional("ccl_drop_list");
	MarkNativeAsOptional("ccl_clear_allcolors");
}
#endif