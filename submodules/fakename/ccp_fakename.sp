#pragma newdecls required

#include ccprocessor

#define PlugName "[CCP] FakeUsername"
#define PlugDesc "Ability to set a fake username in chat msgs"
#define PlugVer "1.0a"

#include std

char fakename[MPL][MNL];

int AccessFlag, ROOT;
int ClientFlags[MPL];

public void OnPluginStart()
{
    ROOT = ReadFlagString("z");

    RegConsoleCmd("sm_fakename", OnCmdUse);

    CreateConVar("ccp_fakename_accessflag", "a", "Access flag or empty, other than the 'z' flag").AddChangeHook(OnAccessChanged);
    AutoExecConfig(true, "ccp_fakename");
}

public void OnMapStart()
{
    _CVAR_INIT_CHANGE(OnAccessChanged, "ccp_fakename_accessflag");
}

_CVAR_ON_CHANGE(OnAccessChanged)
{
    if(!cvar)
        return;
    
    char szFlag[4];
    cvar.GetString(SZ(szFlag));

    AccessFlag = (szFlag[0]) ? ReadFlagString(szFlag) : 0;
}

public Action OnCmdUse(int iClient, int args)
{
    if(args == 1 && iClient && IsClientInGame(iClient) && IsValidClient(iClient))
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
    return ((ClientFlags[iClient] && (ClientFlags[iClient] & ROOT)) || (AccessFlag && (ClientFlags[iClient] & AccessFlag)));
}

