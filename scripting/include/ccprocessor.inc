#if defined _ccprocessor_included
 #endinput
#endif
#define _ccprocessor_included

// Types of message
enum
{
	eMsg_TEAM = 0,
	eMsg_ALL,
	eMsg_CNAME,
	eMsg_RADIO,
	eMsg_SERVER,
	
	eMsg_MAX
};

#define STATUS_LENGTH   16
#define TEAM_LENGTH     32
#define PREFIX_LENGTH   64
#define NAME_LENGTH     128
#define MESSAGE_LENGTH  256

#define MAX_LENGTH      512

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
 *	@param szBind		Core binds ({PROTOTYPE}, {STATUS}, {TEAM}, {PREFIXCO}, {PREFIX}, {NAMECO}, {NAME}, {MSGCO}, {MSG})
 *	@param szBuffer		Buffer with value
 *	@param iSize		Size of buffer
 *
 * 	@noreturn
*/
forward void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize);

/*
 *	Calls when capturing an engine message from the server
 *
 *	@param szMessage			Key of engine message (with symbol[0] = '#')
 *	@param IsPhraseExists		If key of engine message is exists
 *	@param IsTranslated			If key of engine message is translated for LANG_SEVER
 *
 * 	@return					Plugin_Changed	- send message for core processing
								Plugin_Continue - exclude engine message processing
								Plugin_Handled 	- exclude message sending by engine
*/
forward Action cc_proc_OnDefMsg(const char[] szMessage, bool IsPhraseExists, bool IsTranslated);

/*
 *	Calls when the config reading is completed
 *
 *	@noparam
 *
 * 	@noreturn
*/
forward void cc_config_parsed();

/*
 *	Calls before building a message
 *
 *	@param iType		Type of message(see enumiration)
 *
 * 	@noreturn
*/
forward void cc_proc_MsgBroadType(const int iType);

/*
 *	Calls when message is build ended
 *
 *	@param iClient			Sender's index
 *	@param szMessage		Built message
 *
 * 	@noreturn
*/
forward void cc_proc_OnMessageBuilt(int iClient, const char[] szMessage);

/*
 *	Approving the sender's index
 *	Calls when message is ready to send
 *
 *	@param &iClientIndex		Sender's index (<> 0)
 *
 * 	@noreturn
*/
forward void cc_proc_IndexApproval(int &iClientIndex);

/*
 *	Called when action is required on the radio key
 *
 *	@param iClient			Sender's index
 *	@param szRKey			Radio key
 *
 * 	@return					true - restrict, false - otherwise
*/
forward bool cc_proc_RestrictRadio(int iClient, const char[] szRKey);

/*
 *	Get a pallete
 *
 *	@noparam
 *
 * 	@return				List:> Key:Value:Transl
*/
native ArrayList cc_drop_palette();


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
	MarkNativeAsOptional("cc_drop_palette");
	MarkNativeAsOptional("cc_clear_allcolors");
}
#endif