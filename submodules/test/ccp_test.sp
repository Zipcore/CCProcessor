#pragma newdecls required

#include ccprocessor

#define GREEN   "{G}"
#define RED     "{R}"

#define P_LEVEL_MSG     1
#define P_LEVEL_NAME    1

public void OnPluginStart()
{
    RegConsoleCmd("ccl_test", Cmd_ccl);
    RegConsoleCmd("ccl_namecolor", cmd_ccl_name);
    RegConsoleCmd("ccl_msgcolor", cmd_ccl_msg);
    RegConsoleCmd("ccl_servercolor", cmd_ccl_server);
    RegConsoleCmd("ccl_say", cmd_ccl_say);
}

public Action Cmd_ccl(int iClient, int iArgs)
{
    PrintToChatAll("%sHello, i'm a %sServer!", GREEN, RED);
    if(iClient && IsClientInGame(iClient))
        PrintToChat(iClient, "%sHello, %s%N", GREEN, RED, iClient);

    return Plugin_Handled;
}

bool IsEnabled_Name[MAXPLAYERS+1];
bool IsEnabled_Msg[MAXPLAYERS+1];
bool IsEnabled_Server;

public bool OnClientConnect(int iClient, char[] rejectmsg, int maxlen)
{
    IsEnabled_Name[iClient] = false;
    IsEnabled_Msg[iClient] = false;

    return true;
}

public Action cmd_ccl_name(int iClient, int iArgs)
{
    if(iClient && IsClientInGame(iClient))
    {
        IsEnabled_Name[iClient] = !IsEnabled_Name[iClient];
    
        PrintToChat(iClient, "%sName Color: %s%b", GREEN, RED, IsEnabled_Name[iClient]);
    }
        
    return Plugin_Handled;
}

public Action cmd_ccl_msg(int iClient, int iArgs)
{
    if(iClient && IsClientInGame(iClient))
    {
        IsEnabled_Msg[iClient] = !IsEnabled_Msg[iClient];
    
        PrintToChat(iClient, "%sMsg color: %s%b", GREEN, RED, IsEnabled_Msg[iClient]);
    }
        
    return Plugin_Handled;
}

public Action cmd_ccl_server(int iClient, int iArgs)
{
    IsEnabled_Server = !IsEnabled_Server;
    PrintToChatAll("%sServer color: %s%b", GREEN, RED, IsEnabled_Server);

    return Plugin_Handled;
}

public Action cmd_ccl_say(int iClient, int iArgs)
{
    PrintToChatAll("test");
    return Plugin_Handled;
}

public void cc_proc_RebuildString(int iClient, int &plevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!strcmp(szBind, "{MSG}") && IsEnabled_Msg[iClient] && plevel < P_LEVEL_MSG)
    {
        plevel = P_LEVEL_MSG;
        cc_clear_allcolors(szBuffer, iSize);

        Format(szBuffer, iSize, "%s%s", GREEN, szBuffer);
    }

    else if(!strcmp(szBind, "{NAME}") && IsEnabled_Name[iClient] && plevel < P_LEVEL_NAME)
    {
        plevel = P_LEVEL_NAME;
        cc_clear_allcolors(szBuffer, iSize);
        
        Format(szBuffer, iSize, "%s%s", RED, szBuffer);
    }
}

public bool cc_proc_OnServerMsg(char[] szMessage, int MsgLen)
{
    if(IsEnabled_Server)
    {
        Format(szMessage, MsgLen, "%s%s", GREEN, szMessage);
    }

    return true;
}