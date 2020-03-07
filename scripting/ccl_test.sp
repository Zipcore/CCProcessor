#pragma newdecls required

#include ccl_proc

#define GREEN   "{G}"
#define RED     "{R}"

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
    PrintToChatAll("%sHello, i'm %sServer!", GREEN, RED);
    if(iClient)
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
    if(iClient)
    {
        IsEnabled_Name[iClient] = !IsEnabled_Name[iClient];
    
        PrintToChat(iClient, "%sName Color: %s%b", GREEN, RED, IsEnabled_Name[iClient]);
    }
        
    return Plugin_Handled;
}

public Action cmd_ccl_msg(int iClient, int iArgs)
{
    if(iClient)
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
    PrintToChatAll("Lol");
    return Plugin_Handled;
}

public void ccl_proc_RebuildString(int iClient, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!strcmp(szBind, "{MSG}") && IsEnabled_Msg[iClient])
    {
        Format(szBuffer, iSize, "%s%s", GREEN, szBuffer);
    }

    if(!strcmp(szBind, "{NAME}") && IsEnabled_Name[iClient])
    {
        Format(szBuffer, iSize, "%s%s", RED, szBuffer);
    }
}

public void ccl_proc_OnServerMsg(char[] szMessage, int MsgLen)
{
    if(IsEnabled_Server)
    {
        Format(szMessage, MsgLen, "%s%s", GREEN, szMessage);
    }
}