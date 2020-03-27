#if defined _ccprocessor_included
 #endinput
#endif
#define _ccprocessor_included


/* 
	Skip color keys in a client message? 
	Calling before ccl_proc_RebuildString()
*/
forward bool cc_proc_SkipColorsInMsg(int iClient);

/* 
	Prototype properties of the client message
	const char[] szBind = {TEAM}, {NAME}, {MSG}, {STATUS}
*/
forward void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize);

/* Message sended by server */
forward bool cc_proc_OnServerMsg(char[] szMessage, int MsgLen);

/* On config parsed success */
forward void cc_config_parsed();

/* 
	Called when sending a message about changing the player's nickname 
	@ return 	Plugin_Continue - send msg / Plugin_Handle - otherwise 
*/
forward Action cc_proc_OnUsernameChangedMsg();

native ArrayList cc_drop_list(bool IsTriggers);

native void cc_clear_allcolors(char[] szBuffer, int iSize);

public SharedPlugin __pl_ccprocessor= 
{
	name = "ccprocessor",
	file = "ccprocessor.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ccprocessor_SetNTVOptional()
{
	MarkNativeAsOptional("cc_drop_list");
	MarkNativeAsOptional("cc_clear_allcolors");
}
#endif