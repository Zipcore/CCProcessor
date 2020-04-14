#pragma newdecls required

#include ccprocessor
#include clientprefs

public Plugin myinfo = 
{
	name = "[CCP] Individual Prefix",
	author = "nullent?",
	description = "Sets an individual prefix for the player based on the criteria",
	version = "1.0.2",
	url = "discord.gg/ChTyPUG"
};

#define SZ(%0)	%0, sizeof(%0)
#define BUILD(%0,%1) BuildPath(Path_SM, SZ(%0), %1)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1

#define PATH  "configs/c_var/customprefix/customprefix.ini"

enum eAccess
{
    eNone = 0,
    eAuth,
    eFlag,
    eGroup
};

enum struct eIndividualPrefix
{
    eAccess eIType;
    char eIPrefix[PREFIX_LENGTH];

    void Clear()
    {
        this.eIType = eNone;
        this.eIPrefix = "";
    }
}

ArrayList aPlayerPrefixes[MPL];
ArrayList aPrefixBase;

Cookie cooPrefix;

char ClientPrefix[MPL][PREFIX_LENGTH];

int PLEVEL;

public void OnPluginStart()
{
    LoadTranslations("ccproc.phrases");

    aPrefixBase = new ArrayList(PREFIX_LENGTH, 0);
    cooPrefix = new Cookie("ccp_individprefix", "Player individual prefix", CookieAccess_Private);

    CreateConVar("ccp_indprefix_priority", "1", "Priority of replacing the prefix", _, true, 0.0).AddChangeHook(OnPriorChange);
    AutoExecConfig(true, "ccp_indprefix", "ccprocessor");
    
    RegConsoleCmd("sm_prefix", Cmd_Prefix);
}

_CVAR_ON_CHANGE(OnPriorChange)
{
    PLEVEL = (cvar) ? cvar.IntValue : 1;
}

public void OnMapStart()
{
    _CVAR_INIT_CHANGE(OnPriorChange, "ccp_indprefix_priority");

    char szFullPath[PMP];
    BUILD(szFullPath, PATH);

    if(!FileExists(szFullPath))
    {
        LogError("Where is my config: %s ???", szFullPath);
        return;
    }

    aPrefixBase.Clear();

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;

    int iLine;

    if(smParser.ParseFile(szFullPath, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %i", szFullPath, iLine);
}

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(!StrEqual(name, "Prefixes"))
        aPrefixBase.PushString(name);

    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    static eIndividualPrefix eIBuffer;

    if(CharToAccessType(sValue) != eNone)
        eIBuffer.eIType = CharToAccessType(sValue);
    
    else strcopy(SZ(eIBuffer.eIPrefix), sValue);

    if(eIBuffer.eIType != eNone && eIBuffer.eIPrefix[0])
    {
        aPrefixBase.PushArray(SZ(eIBuffer));
        eIBuffer.Clear();
    }

    return SMCParse_Continue;
}

public void OnClientPutInServer(int iClient)
{
    if(!aPlayerPrefixes[iClient])
        aPlayerPrefixes[iClient] = new ArrayList(PREFIX_LENGTH, 0);
    
    aPlayerPrefixes[iClient].Clear();
    ClientPrefix[iClient][0] = 0;

    if(!IsFakeClient(iClient))
        GetPlayerPrefixes(iClient, eAuth);
}

public void OnClientPostAdminCheck(int iClient)
{
    GetPlayerPrefixes(iClient, eFlag);
    GetPlayerPrefixes(iClient, eGroup);
}

void ClientCookie(int iClient)
{
    char szAccess[16];
    cooPrefix.Get(iClient, SZ(szAccess));

    eAccess eAPlayer = CharToAccessType(szAccess);
    if(eAPlayer != eNone)
    {
        eIndividualPrefix eIBuffer;
        for(int i; i < aPlayerPrefixes[iClient].Length; i++)
        {
            aPlayerPrefixes[iClient].GetArray(i, SZ(eIBuffer));
            if(eIBuffer.eIType != eAPlayer)
                continue;
            
            ClientPrefix[iClient] = eIBuffer.eIPrefix;
            break;
        }
    }
}

void GetPlayerPrefixes(int iClient, eAccess eAValue)
{
    switch(eAValue)
    {
        case eAuth:
        {
            char szAuth[32];
            if(!GetClientAuthId(iClient, AuthId_Engine, SZ(szAuth)))
                return;
            
            int pos = aPrefixBase.FindString(szAuth);
            if(pos == -1)
                return;
            
            eIndividualPrefix eIBuffer;
            aPrefixBase.GetArray(pos+1, SZ(eIBuffer));

            aPlayerPrefixes[iClient].PushArray(SZ(eIBuffer));
        }

        case eFlag:
        {
            int iRights = GetUserFlagBits(iClient);
            char szFlag[4];

            for(int i; i < aPrefixBase.Length; i+=2)
            {
                aPrefixBase.GetString(i, SZ(szFlag));
                if(strlen(szFlag) == 1 && (iRights & ReadFlagString(szFlag)))
                {
                    eIndividualPrefix eIBuffer;
                    aPrefixBase.GetArray(i+1, SZ(eIBuffer));

                    aPlayerPrefixes[iClient].PushArray(SZ(eIBuffer)); 
                }
            }
        }

        case eGroup:
        {
            AdminId aid;
            if((aid = GetUserAdmin(iClient)) == INVALID_ADMIN_ID)
                return;
            
            char szGroup[64];
            int pos;

            for(int i; i < aid.GroupCount; i++)
            {
                aid.GetGroup(i, SZ(szGroup));
                if((pos = aPrefixBase.FindString(szGroup)) == -1)
                    continue;
                
                eIndividualPrefix eIBuffer;
                aPrefixBase.GetArray(pos+1, SZ(eIBuffer));

                aPlayerPrefixes[iClient].PushArray(SZ(eIBuffer)); 
            }
        }
    }

    ClientCookie(iClient);
}

public Action Cmd_Prefix(int iClient, int args)
{
    if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient) && aPlayerPrefixes[iClient].Length)
    {
        Menu menu = PrefixesList(iClient);
        if(menu)
            menu.Display(iClient, MENU_TIME_FOREVER);
    }
    
    return Plugin_Handled;
}

Menu PrefixesList(int iClient)
{
    Menu hMenu;

    if(aPlayerPrefixes[iClient].Length)
    {
        SetGlobalTransTarget(iClient);

        hMenu = new Menu(PrefList_CallBack);
        hMenu.SetTitle("%t \n \n", "list_of_prefix");

        char szBuffer[PREFIX_LENGTH], szOpt[8];
        eIndividualPrefix eIBuffer;
        int DRAWTYPE;

        FormatEx(SZ(szBuffer), "%t \n \n", "ccp_disable");
        hMenu.AddItem("rem", szBuffer, (ClientPrefix[iClient][0]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

        for(int i; i < aPlayerPrefixes[iClient].Length; i++)
        {
            aPlayerPrefixes[iClient].GetArray(i, SZ(eIBuffer));

            szOpt = AccessTypeToChar(eIBuffer.eIType);
            szBuffer = eIBuffer.eIPrefix;

            DRAWTYPE = (!strcmp(szBuffer, ClientPrefix[iClient])) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            
            cc_clear_allcolors(SZ(szBuffer));

            hMenu.AddItem(szOpt, szBuffer, DRAWTYPE);
        }
    }

    return hMenu;
}

public int PrefList_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select:
        {
            char szOpt[8];
            hMenu.GetItem(iOpt2, SZ(szOpt));

            if(!StrEqual(szOpt, "rem"))
            {
                eAccess eAType = CharToAccessType(szOpt);
                eIndividualPrefix eIBuffer;
                
                for(int i; i < aPlayerPrefixes[iClient].Length; i++)
                {
                    aPlayerPrefixes[iClient].GetArray(i, SZ(eIBuffer));

                    if(eAType != eIBuffer.eIType)
                        continue;
                    
                    ClientPrefix[iClient] = eIBuffer.eIPrefix;
                }
            }
            else ClientPrefix[iClient][0] = 0;

            cooPrefix.Set(iClient, (StrEqual(szOpt, "rem")) ? "" : szOpt);

            SetGlobalTransTarget(iClient);
            PrintToChat(iClient, "%t", "ccp_prefix_changed", (!ClientPrefix[iClient][0]) ? "null" : ClientPrefix[iClient]);                
        }
    }
}

public void cc_proc_RebuildString(int iClient, int &plevel, const char[] szBind, char[] szBuffer, int iSize)
{   
    if(!StrEqual(szBind, "{PREFIX}") || PLEVEL < plevel || !ClientPrefix[iClient][0])
        return;

    plevel = PLEVEL;
    FormatEx(
        szBuffer, iSize, "%s", ClientPrefix[iClient]
    );
}

// auth, flag, group
eAccess CharToAccessType(const char[] szAccess)
{
    return (!strcmp(szAccess, "auth")) ? eAuth : (!strcmp(szAccess, "flag")) ? eFlag : (!strcmp(szAccess, "group")) ? eGroup : eNone;
}

char AccessTypeToChar(eAccess eAValue)
{
    char szAccess[8];

    switch(eAValue)
    {
        case eAuth: szAccess = "auth";
        case eFlag: szAccess = "flag";
        case eGroup: szAccess = "group";
    }

    return szAccess;
}