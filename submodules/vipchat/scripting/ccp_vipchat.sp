#pragma newdecls required

#include vip_core
#include ccprocessor
#include clientprefs

#define PlugName "[CCP] VIP Chat"
#define PlugDesc "Chat features for VIP by user R1KO"
#define PlugVer "1.3"

#include std

#define _CONFIG_PATH "data\\vip\\modules\\chat.ini"

ArrayList aTriggers;
ArrayList aPhrases;


/* Env:
    0 - Prefix
    1 - Name
    2 - Message
*/

enum
{
    E_CPrefix = 0,
    E_CName,
    E_CMessage,
    E_Prefix
};

int nLevel[3];

char EnvColor[MPL][3][10];
char ClientPrefix[MPL][128];

char ccl_current_feature[MPL][18];

bool bCustom[MPL];

ArrayList aBuffer;
Handle coFeatures[4];

bool blate;

int Section;

bool ColoredPrefix[MPL];

ArrayList aGroups;
ArrayList aFeature;

static const char szFeatures[][] = {"vip_prefix_color", "vip_name_color", "vip_message_color", "vip_prefix"};

static const char szCVars[][] = {"vip_prefix_pririty", "vip_name_priority", "vip_message_priority"};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    blate = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("ccproc.phrases");
    LoadTranslations("vip_ccpchat.phrases");
    LoadTranslations("vip_modules.phrases");

    aBuffer = new ArrayList(128, 0);
    aTriggers = new ArrayList(1);
    aPhrases = new ArrayList(1);

    CreateConVar(szCVars[E_CPrefix], "2", "The priority level to change the color of the prefix", _, true, 0.0).AddChangeHook(OnChangedPPrefix);
    CreateConVar(szCVars[E_CName], "2", "The priority level to change the color of the username", _, true, 0.0).AddChangeHook(OnChangedPName);
    CreateConVar(szCVars[E_CMessage], "2", "The priority level to change the color of the usermessage", _, true, 0.0).AddChangeHook(OnChangedPMessage);

    AutoExecConfig(true, "vip_chat", "ccprocessor");

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded(); 

    for(int i; i < sizeof(szFeatures); i++)
        coFeatures[i] = RegClientCookie(szFeatures[i], szFeatures[i], CookieAccess_Private);
}

public void OnMapStart()
{
    _CVAR_INIT_CHANGE(OnChangedPPrefix, szCVars[E_CPrefix]);
    _CVAR_INIT_CHANGE(OnChangedPName, szCVars[E_CName]);
    _CVAR_INIT_CHANGE(OnChangedPMessage, szCVars[E_CMessage]);

    char path[PMP];
    BUILD(path, _CONFIG_PATH);
    
    if(!FileExists(path))
        SetFailState("Where is my config: %s ???", path);

    aBuffer.Clear();

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;
    smParser.OnLeaveSection = OnLeave;
    smParser.OnEnd = OnParseEnded;

    int iLine;

    if(smParser.ParseFile(path, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %d", path, iLine);
}

_CVAR_ON_CHANGE(OnChangedPPrefix)
{
    if(cvar)
        nLevel[E_CPrefix] = cvar.IntValue;
}

_CVAR_ON_CHANGE(OnChangedPName)
{
    if(cvar)
        nLevel[E_CName] = cvar.IntValue;
}

_CVAR_ON_CHANGE(OnChangedPMessage)
{
    if(cvar)
        nLevel[E_CMessage] = cvar.IntValue;
}

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(!strcmp(name, "chat_settings"))
    {
        Section = 0;

        aFeature = new ArrayList(128, 0);
        aGroups = new ArrayList(128, 0);
    }
        
    else if(!strcmp(name, szFeatures[E_CPrefix]) || !strcmp(name, szFeatures[E_CName]) || !strcmp(name, szFeatures[E_CMessage]) || !strcmp(name, szFeatures[E_Prefix]))
    {
        if(aBuffer.FindString(name) != -1)
            return SMCParse_HaltFail;
        
        aFeature.Clear();
        aBuffer.PushString(name);

        Section = 1;
    }

    else
    {
        aFeature.PushString(name);
        aGroups.Clear();

        Section = 2;
    }

    return SMCParse_Continue;
}

SMCResult OnLeave(SMCParser smc)
{
    if(Section == 2)
        aFeature.Push(aGroups.Clone());
    
    else if(Section == 1)
        aBuffer.Push(aFeature.Clone());

    Section--;

    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    aGroups.PushString(sValue);

    return SMCParse_Continue;
}

public void OnParseEnded(SMCParser smc, bool halted, bool failed)
{
    if(halted || failed)
        SetFailState("Configuration reading error");

    delete aFeature;
    delete aGroups;

    if(blate) 
    {
        cc_config_parsed();
        blate = false;
    }
}

public void cc_config_parsed()
{
    delete aTriggers;
    delete aPhrases;

    aTriggers = cc_drop_list(true);
    aPhrases = cc_drop_list(false);
}

public void VIP_OnVIPLoaded()
{
    for(int i; i < sizeof(szFeatures); i++)
        VIP_RegisterFeature(szFeatures[i], INT, SELECTABLE, OnSelected_Feature, OnDisplay_Feature, OnFeatureDraw);
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") != FeatureStatus_Available)
        return;
    
    for(int i; i < sizeof(szFeatures); i++)
        VIP_UnregisterFeature(szFeatures[i]);
}

public bool OnSelected_Feature(int iClient, const char[] szFeature)
{
    FeatureMenu(iClient, szFeature).Display(iClient, MENU_TIME_FOREVER);
    return false;
}

public int OnFeatureDraw(int iClient, const char[] szFeature, int iStyle)
{
    if(!strcmp(szFeature, szFeatures[E_CPrefix]) && (!ClientPrefix[iClient][0] || ColoredPrefix[iClient]))
        return ITEMDRAW_DISABLED;

    return iStyle;
}

public bool OnDisplay_Feature(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
    SetGlobalTransTarget(iClient);

    char szFValue[64];

    if(!strcmp(szFeature, szFeatures[E_Prefix]))
        strcopy(SZ(szFValue), ClientPrefix[iClient]);
    
    else
    {
        strcopy(SZ(szFValue), EnvColor[iClient][GetFeaturePos(szFeature)]);

        if(szFValue[0] && aTriggers && aPhrases)
        {
            aTriggers.GetString(aTriggers.FindString(szFValue) - 1, SZ(szFValue));
            aPhrases.GetString(aPhrases.FindString(szFValue) + 1, SZ(szFValue));

            Format(SZ(szFValue), "%t", szFValue);
        }
    }

    cc_clear_allcolors(SZ(szFValue));

    TrimString(szFValue);
    if(!szFValue[0])
        FormatEx(SZ(szFValue), "%t", "empty_value");

    FormatEx(szDisplay, iMaxLength, "%t [%s]", szFeature, szFValue);

    return true;
}

public void OnClientPutInServer(int iClient)
{
    for(int i; i < sizeof(szFeatures) -1; i++)
        EnvColor[iClient][i][0] = 0;
    
    ClientPrefix[iClient][0] = 0;
    ColoredPrefix[iClient] = false;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    for(int i; i < sizeof(szFeatures) -1; i++)
        if(VIP_IsClientFeatureUse(iClient, szFeatures[i]))
            GetClientCookie(iClient, coFeatures[i], EnvColor[iClient][i], sizeof(EnvColor[][]));
    
    if(VIP_IsClientFeatureUse(iClient, szFeatures[E_Prefix]))
    {
        ColoredPrefix[iClient] = VIP_GetClientFeatureInt(iClient, szFeatures[E_Prefix]) == 2;
        GetClientCookie(iClient, coFeatures[E_Prefix], ClientPrefix[iClient], sizeof(ClientPrefix[]));
    }

    if(ColoredPrefix[iClient])
    {
        /*if(VIP_IsClientFeatureUse(iClient, szFeatures[E_CPrefix]))
            VIP_RemoveClientFeature(iClient, szFeatures[E_CPrefix]);*/
        
        EnvColor[iClient][E_CPrefix][0] = 0;
    }  
}

Menu FeatureMenu(int iClient, const char[] szFeature)
{
    Menu hMenu;
    char szGroup[128];
    char szBuffer[PMP];
    char szOpt[64];
    ArrayList arr;
    int iPos[2];

    SetGlobalTransTarget(iClient);

    strcopy(ccl_current_feature[iClient], sizeof(ccl_current_feature[]), szFeature);
    VIP_GetClientVIPGroup(iClient, SZ(szGroup));
    
    /*
        Array > Feature:Array
            Array > Group:Array
                Array > Strings
    */
    iPos[0] = aBuffer.FindString(szFeature);
    if(iPos[0] == -1)
        return hMenu;

    iPos[1] = view_as<ArrayList>(aBuffer.Get(iPos[0]+1)).FindString(szGroup);
    if(iPos[1] == -1)
        return hMenu;
    
    arr = view_as<ArrayList>(aBuffer.Get(iPos[0] + 1)).Get(iPos[1] + 1);
    if(!arr)
    {
        LogError("Failed on get array");
        return hMenu;
    }
        
    hMenu = new Menu(FeatureMenu_CallBack);

    FormatEx(SZ(szBuffer), "%s_title", szFeature);
    hMenu.SetTitle("%t \n \n", szBuffer);

    FormatEx(SZ(szBuffer), "%t \n \n", "disable_this");
    hMenu.AddItem("disable", szBuffer);

    if(arr.FindString("custom") != -1)
    {
        FormatEx(SZ(szBuffer), "%t \n \n", "custom_value");
        hMenu.AddItem("custom", szBuffer);
    }

    for(int i; i < arr.Length; i++)
    {
        arr.GetString(i, SZ(szOpt));
        if(!szOpt[0] || !strcmp(szOpt, "custom"))
            continue;

        if(!StrEqual(szFeature, szFeatures[E_Prefix]))
        {
            if((iPos[0] = aPhrases.FindString(szOpt)) == -1)
                continue;
            
            aPhrases.GetString(iPos[0] + 1, SZ(szBuffer));
        }

        else strcopy(SZ(szBuffer), szOpt);

        Format(SZ(szBuffer), "%t", szBuffer);
        cc_clear_allcolors(SZ(szBuffer));
            
        hMenu.AddItem(szOpt, szBuffer);
    }

    return hMenu;    
}

public int FeatureMenu_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select:
        {
            char szOpt2[128];
            hMenu.GetItem(iOpt2, SZ(szOpt2));

            if(!strcmp(szOpt2, "custom"))
            {
                bCustom[iClient] = true;

                PrintToChat(iClient, "%t", "ccp_custom_value");

                return;
            }

            else if(!strcmp(szOpt2, "disable"))
            {
                UpdateValueByFeature(iClient, ccl_current_feature[iClient], NULL_STRING);
                VIP_SendClientVIPMenu(iClient, true);
                return;
            }

            SetGlobalTransTarget(iClient);
            if(StrEqual(ccl_current_feature[iClient], szFeatures[E_Prefix]))
                Format(SZ(szOpt2), "%t", szOpt2);

            else aTriggers.GetString(aTriggers.FindString(szOpt2) + 1, SZ(szOpt2));        

            UpdateValueByFeature(iClient, ccl_current_feature[iClient], szOpt2);
        }
    }
}

void UpdateValueByFeature(int iClient, const char[] szFeature, const char[] szValue)
{
    if(StrEqual(szFeature, szFeatures[E_Prefix]))
    {
        strcopy(ClientPrefix[iClient], sizeof(ClientPrefix[]), szValue);

        if(!ColoredPrefix[iClient])
            cc_clear_allcolors(ClientPrefix[iClient], sizeof(ClientPrefix[]));
    }
        
    else strcopy(EnvColor[iClient][GetFeaturePos(szFeature)], sizeof(EnvColor[][]), szValue);


    if(!strcmp(szFeature, szFeatures[E_Prefix]) && !ClientPrefix[iClient][0])
    {
        EnvColor[iClient][E_CPrefix][0] = 0;
        SetClientCookie(iClient, coFeatures[E_CPrefix], NULL_STRING);
    }

    SetClientCookie(
        iClient, 
        (!StrEqual(szFeature, szFeatures[E_Prefix])) 
        ? coFeatures[GetFeaturePos(szFeature)] 
        : coFeatures[E_Prefix], 
        szValue
    );

    PrintToChat(iClient, "%t", "ccp_vip_valueupdated");

    VIP_SendClientVIPMenu(iClient, true);
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] args)
{
    if(!IsClientInGame(iClient) || IsFakeClient(iClient) || IsChatTrigger())
        return Plugin_Continue;

    if(bCustom[iClient])
    {
        char szBuffer[128];

        if(!StrEqual(ccl_current_feature[iClient], szFeatures[E_Prefix]))
        {
            int iPos;
            if((iPos = aTriggers.FindString(args)) == -1)
            {
                PrintToChat(iClient, "%t", "ccp_invalid_colorkey");
                return Plugin_Handled;
            }

            aTriggers.GetString(iPos+1, SZ(szBuffer));
        }

        else 
        {
            strcopy(SZ(szBuffer), args);

            if(!ColoredPrefix[iClient])
                cc_clear_allcolors(SZ(szBuffer));
        }
        
        bCustom[iClient] = false;

        UpdateValueByFeature(iClient, ccl_current_feature[iClient], szBuffer);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void cc_proc_RebuildString(int iClient, int &plevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!VIP_IsClientVIP(iClient))
        return;
    
    static int i;
    i = (!strcmp(szBind, "{NAME}")) ? E_CName : (!strcmp(szBind, "{PREFIX}")) ? E_CPrefix : (!strcmp(szBind, "{MSG}")) ? E_CMessage : -1;

    if(i == -1)
        return;
    
    if(nLevel[i] < plevel)
        return;

    plevel = nLevel[i];
    cc_clear_allcolors(szBuffer, iSize);

    switch(i)
    {
        case E_CPrefix:
        {
            FormatEx(
                szBuffer, iSize, "%s%s", 
                (EnvColor[iClient][E_CPrefix][0]) ? EnvColor[iClient][E_CPrefix] : "",
                (ClientPrefix[iClient][0]) ? ClientPrefix[iClient] : ""
            );
        }

        default:
        {
            Format(
                szBuffer, iSize, "%s%s", 
                (EnvColor[iClient][i][0]) ? EnvColor[iClient][i] : "",
                szBuffer
            );
        }
    }
}

int GetFeaturePos(const char[] szFeature)
{
    for(int i; i < sizeof(szFeatures) - 1; i++)
        if(StrEqual(szFeature, szFeatures[i]))
            return i;
    
    return 0;
}
