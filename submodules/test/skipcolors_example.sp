/*
    Disclaimer:
    This is an example of a plugin for allowing a client to openly use color tags in a message
    https://github.com/Nullent/CCProcessor/blob/master/screens/csgo.png
*/

#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] Skip color tags",
	author = "nullent?",
	description = "example",
	version = "1.0",
	url = "discord.gg/ChTyPUG"
};

#define MPL MAXPLAYERS+1

bool EnableSkipping[MPL];

public void OnPluginStart()
{
    RegConsoleCmd("sm_skipcolortag", CmdUse);
}

Action CmdUse(int Client, int args)
{
    if(Client && !IsFakeClient(Client))
        PrintToChat(Client, "{W}Skipping color tags is {G}%s {W}for you", (EnableSkipping[Client] = !EnableSkipping[Client]) ? "enabled" : "disabled");
    
    return Plugin_Handled;
}

public bool cc_proc_SkipColorsInMsg(int Client)
{
    return EnableSkipping[Client];
}

public void OnClientConnected(int Client)
{
    EnableSkipping[Client] = false;
}