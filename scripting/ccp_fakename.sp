#pragma newdecls required

#include ccprocessor

#define STANDART_INFO

#define PlugName "[CCL] FakeUsername"
#define PlugDesc "Ability to set a fake username in chat msgs"
#define PlugVer "1.0"

#include std

char fakename[MPL][MNL];

int AccessFlag;
int ClientFlags[MPL];

public void OnPluginStart()
{
    RegConsoleCmd("sm_fakename", OnSendCmd);

    CreateConVar("ccl_fakename_accessflag", "a", "Access flag or empty, other than the 'z' flag").AddChangeHook(OnAccessChanged);
    AutoExecConfig(true, "ccl_fakename");
}

public void OnMapStart()
{
    HOOKCVAR(OnAccessChanged, "ccl_fakename_accessflag");
}

CVAR_CHANGE(OnAccessChanged)
{
    if(!cvar)
        return;
    
    char szFlag[4];
    cvar.GetString(SZ(szFlag));

    AccessFlag = (szFlag[0]) ? ReadFlagString(szFlag) : 0;
}

public Action OnSendCmd(int iClient, int args)
{
    if(iClient && IsClientInGame(iClient) && args == 1 && IsValidClient(iClient))
        GetCmdArg(1, fakename[iClient], sizeof(fakename[]));

    return Plugin_Handled;
}

public void OnClientPutInServer(int iClient)
{
    fakename[iClient][0] = 0;
    ClientFlags[iClient] = 0;
}

public void OnClientPostAdminCheck(int iClient)
{
    ClientFlags[iClient] = GetUserFlagBits(iClient);
}

public void cc_proc_RebuildString(int iClient, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!strcmp(szBind, "{NAME}") && fakename[iClient][0])
        FormatEx(szBuffer, iSize, fakename[iClient]);
}

bool IsValidClient(int iClient)
{
    if(!ClientFlags[iClient])
        return false;
    
    else if(ClientFlags[iClient] & ReadFlagString("z"))
        return true;

    else if(!AccessFlag)
        return false;
    
    return (ClientFlags[iClient] & AccessFlag) ? true : false;
}

