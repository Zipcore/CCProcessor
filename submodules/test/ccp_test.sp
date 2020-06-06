#pragma newdecls required

#include ccprocessor

#define LEVEL_PRIOR     1

bool EnableSkip;
char testPrefix[PREFIX_LENGTH];

public void OnPluginStart()
{
    RegConsoleCmd("sm_skipcolors", CmdSkip);
    RegConsoleCmd("sm_testserver", CmdTestServer);
    RegConsoleCmd("sm_testprefix", CmdTestPrefix);
}

Action CmdSkip(int Client, int args)
{
    if(Client && IsClientInGame(Client))
        PrintToChatAll("The color skip status was changed to {G}%s", (EnableSkip = !EnableSkip) ? "true" : "false");
    
    return Plugin_Handled;
}

public bool cc_proc_SkipColorsInMsg(int Client)
{
    return EnableSkip;
}

Action CmdTestServer(int Client, int args)
{
    PrintToChatAll("{PI}[Console] {G}Hello, i am a {PI}Server!");
    return Plugin_Handled;
}

Action CmdTestPrefix(int Client, int Args)
{
    if(!testPrefix[0])
        testPrefix = "{PI}[TEST] ";
    else testPrefix[0] = 0;

    PrintToChatAll("The test prefix now is {G}%s", (testPrefix[0]) ? "enabled" : "disabled");

    return Plugin_Handled;
}

int iType;

public void cc_proc_MsgBroadType(const int typeMsg)
{
    iType = typeMsg;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(iType > eMsg_ALL)
        return;
    
    if(!StrEqual(szBind, "{PREFIX}") || !testPrefix[0])
        return;

    if(pLevel > LEVEL_PRIOR)
        return;
    
    pLevel = LEVEL_PRIOR;

    FormatEx(szBuffer, iSize, testPrefix);
}