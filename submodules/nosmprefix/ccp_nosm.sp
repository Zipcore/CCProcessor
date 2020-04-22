#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] No SM prefix",
	author = "nullent?",
	description = "Replaces the standard Sourcemod prefix for server messages",
	version = "1.0",
	url = "discord.gg/ChTyPUG"
};

#define SM_PREFIX "[SM]"

char szPrefix[TEAM_LENGTH];

public void OnPluginStart()
{
    CreateConVar("ccp_nosm_prefix", "[Valve]", "The new value for the prefix").AddChangeHook(OnCvarChanged);
}

public void OnMapStart()
{
    OnCvarChanged(FindConVar("ccp_nosm_prefix"), NULL_STRING, NULL_STRING);
}

public void OnCvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    if(cvar) cvar.GetString(szPrefix, sizeof(szPrefix));
}

public bool cc_proc_OnServerMsg(char[] szMessage, int MsgLen)
{
    ReplaceStringEx(szMessage, MsgLen, SM_PREFIX, szPrefix, -1, -1, true);

    return true;
}

