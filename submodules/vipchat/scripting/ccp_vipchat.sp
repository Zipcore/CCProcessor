#pragma newdecls required

#include vip_core
#include ccprocessor
#include clientprefs

#define PlugName "[CCP] VIP Chat"
#define PlugDesc "Chat features for VIP by user R1KO"
#define PlugVer "1.0"

#include std

ArrayList aTriggers;
ArrayList aPhrases;

char ccl_Name[MPL][16];
char ccl_Prefix_color[MPL][16];
char ccl_Msg[MPL][16];
char ccl_Prefix[MPL][128];

char ccl_current_feature[MPL][64];

bool bCustom[MPL];

static const char szFeatures[][] = {"vip_ccp_name", "vip_ccp_msg", "vip_ccp_prefix", "vip_ccp_prefix_color"};

#define CNAME       0
#define CMSG        1
#define CPREFIX     2
#define CPRECOLOR   3

ArrayList aBuffer;
Handle coFeatures[4];

bool blate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    blate = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    aBuffer = new ArrayList(PMP, 0);

    LoadTranslations("ccproc.phrases");
    LoadTranslations("vip_ccpchat.phrases");
    LoadTranslations("vip_modules.phrases");

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded(); 

    for(int i; i < sizeof(szFeatures); i++)
        coFeatures[i] = RegClientCookie(szFeatures[i], szFeatures[i], CookieAccess_Private);
}

#define _CONFIG_PATH "data\\vip\\modules\\chat.ini"

public void OnMapStart()
{
    char path[PMP];
    BUILD(path, _CONFIG_PATH);
    
    if(!FileExists(path))
        SetFailState("Where is my config: %s ???", path);

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;
    smParser.OnLeaveSection = OnLeave;
    smParser.OnEnd = OnParseEnded;

    int iLine;

    if(smParser.ParseFile(path, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %d", path, iLine);
}

int Section;

ArrayList aGroups;
ArrayList aFeature;

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(!strcmp(name, "chat_settings"))
    {
        Section = 0;

        if(!aFeature)
            aFeature = new ArrayList(128, 0);
        
        if(!aGroups)
            aGroups = new ArrayList(128, 0);
    }
        
    
    else if(!strcmp(name, szFeatures[CNAME]) || !strcmp(name, szFeatures[CMSG]) || !strcmp(name, szFeatures[CPREFIX]) || !strcmp(name, szFeatures[CPRECOLOR]))
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
    {
        LogError("Parse failed");
        return;
    }

    if(aFeature)
        delete aFeature;
    if(aGroups)
        delete aGroups;

    if(blate) 
    {
        //LogMessage("Late");
        cc_config_parsed();
        blate = false;
    }
}

public void cc_config_parsed()
{
    if(aTriggers)
        delete aTriggers;
    if(aPhrases)
        delete aPhrases;

    aTriggers = cc_drop_list(true);
    aPhrases = cc_drop_list(false);
}

public void VIP_OnVIPLoaded()
{
    for(int i; i < sizeof(szFeatures); i++)
        VIP_RegisterFeature(szFeatures[i], VIP_NULL, SELECTABLE, OnSelected_Feature, OnDisplay_Feature, OnFeatureDraw);
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
    if(!strcmp(szFeature, szFeatures[CPRECOLOR]) && !ccl_Prefix[iClient][0])
        return ITEMDRAW_DISABLED;

    return iStyle;
}

public bool OnDisplay_Feature(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{

    SetGlobalTransTarget(iClient);

    char szFValue[128];

    if(!strcmp(szFeature, szFeatures[CPREFIX]))
        strcopy(SZ(szFValue), ccl_Prefix[iClient]);
    
    else
    {
        strcopy(
            SZ(szFValue), 
            (!strcmp(szFeature, szFeatures[CPRECOLOR])) ? ccl_Prefix_color[iClient] :
            (!strcmp(szFeature, szFeatures[CMSG])) ? ccl_Msg[iClient] : ccl_Name[iClient]
        );

        //LogMessage(szFValue);

        if(szFValue[0])
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
    ccl_Name[iClient][0] = 0;
    ccl_Prefix[iClient][0] = 0;
    ccl_Msg[iClient][0] = 0;
    ccl_Prefix_color[iClient][0] = 0;
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    char szBuffer[128];

    for(int i; i < sizeof(szFeatures); i++)
    {
        GetClientCookie(iClient, coFeatures[i], SZ(szBuffer));
        if(!szBuffer[0])
            continue;
        
        switch(i)
        {
            case CNAME: ccl_Name[iClient][0] = szBuffer[0];
            case CMSG:  ccl_Msg[iClient][0] = szBuffer[0];
            case CPREFIX: ccl_Prefix[iClient] = szBuffer;
            case CPRECOLOR: ccl_Prefix_color[iClient][0] = szBuffer[0];
        }
    }
}

Menu FeatureMenu(int iClient, const char[] szFeature)
{
    Menu hMenu;
    char szGroup[128];
    char szBuffer[PMP];
    char szOpt[PMP];
    ArrayList arr;
    int iPos[2];

    //LogMessage("Feature set: %s", szFeature);

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

    FormatEx(SZ(szBuffer), "%t \n \n", "VIP_Disable");
    hMenu.AddItem("disable", szBuffer);

    if(arr.FindString("custom") != -1)
    {
        FormatEx(SZ(szBuffer), "%t \n \n", "custom");
        hMenu.AddItem("custom", szBuffer);
    }

    for(int i; i < arr.Length; i++)
    {
        arr.GetString(i, SZ(szOpt));

        //LogMessage("Option : %s", szOpt);
        if(!szOpt[0] || !strcmp(szOpt, "custom"))
            continue;
        
        /*
            Array:Translation -> Prefix
            Array:ColorKey ->  Phrase
        */

        if(!StrEqual(szFeature, szFeatures[CPREFIX]))
        {
            //LogMessage("Feature != prefix");

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
            char szOpt2[PMP];
            hMenu.GetItem(iOpt2, SZ(szOpt2));

            if(!strcmp(szOpt2, "custom"))
            {
                bCustom[iClient] = true;

                PrintToChat(iClient, "%t", "ccl_vip_write");

                return;
            }
            else if(!strcmp(szOpt2, "disable"))
            {
                UpdateValueByFeature(iClient, ccl_current_feature[iClient], NULL_STRING);
                VIP_SendClientVIPMenu(iClient, true);
                return;
            }

            SetGlobalTransTarget(iClient);
            if(StrEqual(ccl_current_feature[iClient], szFeatures[CPREFIX]))
                Format(SZ(szOpt2), "%t", szOpt2);

            else aTriggers.GetString(aTriggers.FindString(szOpt2) + 1, SZ(szOpt2));        

            UpdateValueByFeature(iClient, ccl_current_feature[iClient], szOpt2);
        }
    }
}

void UpdateValueByFeature(int iClient, const char[] szFeature, const char[] szValue)
{
    strcopy(
        (!strcmp(szFeature, szFeatures[CNAME])) ? ccl_Name[iClient] :
        (!strcmp(szFeature, szFeatures[CPRECOLOR])) ? ccl_Prefix_color[iClient] : 
        (!strcmp(szFeature, szFeatures[CMSG])) ? ccl_Msg[iClient] : ccl_Prefix[iClient], 
        (!strcmp(szFeature, szFeatures[CPREFIX])) ? sizeof(ccl_Prefix[]) : sizeof(ccl_Msg[]), 
        szValue
    );

    if(!strcmp(szFeature, szFeatures[CPREFIX]))
    {
        if(!ccl_Prefix[iClient][0])
        {
            ccl_Prefix_color[iClient][0] = 0;

            SetClientCookie(iClient, coFeatures[CPRECOLOR], NULL_STRING);
        }
    }

    SetClientCookie(iClient, coFeatures[GetFeaturePos(szFeature)], szValue);

    PrintToChat(iClient, "%t", "ccl_vip_valueupdated");

    VIP_SendClientVIPMenu(iClient, true);
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] args)
{
    if(!IsClientInGame(iClient) || IsFakeClient(iClient) || IsChatTrigger())
        return Plugin_Continue;

    if(bCustom[iClient])
    {
        int iPos;

        char szBuffer[MPL];
        if(!StrEqual(ccl_current_feature[iClient], szFeatures[CPREFIX]))
        {
            if((iPos = aTriggers.FindString(args)) == -1)
            {
                PrintToChat(iClient, "%t", "ccl_invalid_colorkey");
                return Plugin_Handled;
            }

            aTriggers.GetString(iPos+1, SZ(szBuffer));
        }
        else strcopy(SZ(szBuffer), args);
        
        bCustom[iClient] = false;

        UpdateValueByFeature(iClient, ccl_current_feature[iClient], szBuffer);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void cc_proc_RebuildString(int iClient, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!VIP_IsClientVIP(iClient))
        return;
    
    if(!strcmp(szBind, "{NAME}"))
    {
        Format(
            szBuffer, iSize, "%s%s", 
            (ccl_Name[iClient][0]) ? ccl_Name[iClient] : "",
            szBuffer
        );

    }

    else if(!strcmp(szBind, "{MSG}"))
    {
        Format(szBuffer, iSize, "%s%s", (ccl_Msg[iClient][0]) ? ccl_Msg[iClient] : "", szBuffer);
    }

    else if(!strcmp(szBind, "{PREFIX}"))
    {
        FormatEx(
            szBuffer, iSize, "%s%s", 
            (ccl_Prefix_color[iClient][0]) ? ccl_Prefix_color[iClient] : "",
            (ccl_Prefix[iClient][0]) ? ccl_Prefix[iClient] : ""
        )
    }
}

int GetFeaturePos(const char[] szFeature)
{
    for(int i; i < sizeof(szFeatures); i++)
        if(StrEqual(szFeature, szFeatures[i]))
            return i;
    
    return -1;
}
