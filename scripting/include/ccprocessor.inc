#if defined _ccprocessor_included
 #endinput
#endif
#define _ccprocessor_included

// Types of message
enum
{
    eDefaultMsg = 0,
    eChangeUsername = 2
};

/*
 *	Skip colors in an unprepared message
 *
 *	@param iClient		Client index
 *
 * 	@return				true - skipping / false - otherwise
*/
forward bool cc_proc_SkipColorsInMsg(int iClient);

/*
 *	Calls when building parts of the prototype
 *
 *	@param iClient		Client index
 *	@param &pLevel		Replacement priority
 *	@param szBind		Core binds ({NAME}, {PREFIX}, {PROTOTYPE}, {TEAM}, {STATUS}, {MSG})
 *	@param szBuffer		Buffer with value
 *	@param iSize		Size of buffer
 *
 * 	@noreturn
*/
forward void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize);

/*
 *	Calls when capturing a message from the server
 *
 *	@param szMessage	Server msg
 *	@param MsgLen		Size of msg
 *
 * 	@return				true - send / false - otherwise
*/
forward bool cc_proc_OnServerMsg(char[] szMessage, int MsgLen);

/*
 *	Calls when the config reading is completed
 *
 *	@noparam
 *
 * 	@noreturn
*/
forward void cc_config_parsed();

#pragma deprecated "Now called cc_proc_MsgBroadType()"
forward Action cc_proc_OnUsernameChangedMsg();

/*
 *	Calls before building a message
 *
 *	@param iType		Type of message(see enumiration)
 *
 * 	@noreturn
*/
forward void cc_proc_MsgBroadType(const int iType);


/*
 *	Get a list of values
 *
 *	@param IsTriggers	true - Key:color / false - Key:translation key
 *
 * 	@return				List
*/
native ArrayList cc_drop_list(bool IsTriggers);


/*
 *	Removing colors from a string
 *
 *	@param szBuffer		String buffer
 *	@param iSize		Size of string
 *
 * 	@noreturn
*/
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