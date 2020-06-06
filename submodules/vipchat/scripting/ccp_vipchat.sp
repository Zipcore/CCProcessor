#include UTF-8-string

#pragma newdecls required

#include vip_core
#include ccprocessor
#include clientprefs

public Plugin myinfo = 
{
	name = "[CCP] VIP Chat",
	author = "nullent?",
	description = "Chat features for VIP by user R1KO",
	version = "1.5.0",
	url = "discord.gg/ChTyPUG"
};

#define _CONFIG_PATH "data\\vip\\modules\\chat.ini"

#define SZ(%0)	%0, sizeof(%0)
#define BUILD(%0,%1) BuildPath(Path_SM, SZ(%0), %1)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1

enum
{
    E_CPrefix = 0,
    E_CName,
    E_CMessage,
    E_Prefix,

    E_MAX
};

ArrayList aPalette;

int nLevel[E_MAX];

char ccl_current_feature[MPL][20];

bool bCustom[MPL];

Handle coFeatures[E_MAX];

bool blate;

ArrayList aFeatureList;

static const char g_szFeatures[][] = {"vip_prefix_color", "vip_name_color", "vip_message_color", "vip_prefix"};


/* Env:
    0 - Prefix
    1 - Name
    2 - Message
*/

enum struct TemplatePart
{
    // Color value or prefix key
    // char m_szValue[PREFIX_LENGTH];

    // translation key will be interpreted in the client env.
    char m_szTranslationKey[PREFIX_LENGTH];

    char m_szVIPGroup[PREFIX_LENGTH];

    char m_szFeature[PREFIX_LENGTH];

    char GetKey()
    {
        return this.m_szTranslationKey;
    }

    void SetKey(const char[] szKey)
    {
        strcopy(this.m_szTranslationKey, strlen(szKey) + 1, szKey);
    }

    bool IsPartEmpty()
    {
        return !this.m_szTranslationKey[0];
    }

    char GetGroup()
    {
        return this.m_szVIPGroup;
    }

    void SetGroup(const char[] szGroup)
    {
        strcopy(this.m_szTranslationKey, strlen(szGroup) + 1, szGroup);
    }

    char GetFeature()
    {
        return this.m_szFeature;
    }

    void SetFeature(const char[] szFeature)
    {
        strcopy(this.m_szTranslationKey, strlen(szFeature) + 1, szFeature);
    }

    bool IsValidPart()
    {
        return !this.IsPartEmpty() && this.m_szFeature[0] && this.m_szVIPGroup[0];
    }

    bool IsEqualGroup(const char[] szGroup)
    {
        return UTF8StrEqual(szGroup, this.m_szVIPGroup);
    }

    int GetFeatureNum()
    {
        int i = -1;
        while(i++ < sizeof(g_szFeatures)-1)
            if(StrEqual(g_szFeatures[i], this.GetFeature()))
                return i;
            
        return i = -1;
    }
    
    void ResetPart()
    {
        this.m_szTranslationKey[0] = 0;
        this.m_szVIPGroup[0] = 0;
        this.m_szFeature[0] = 0;
    }
}

enum struct ClientTemplate
{
    TemplatePart m_tpCPrefix;
    TemplatePart m_tpLPrefix;
    TemplatePart m_tpCName;
    TemplatePart m_tpCMessage;

    TemplatePart m_tpBuffer;

    char m_szVIPGroup[PREFIX_LENGTH];

    void WorkWith(const char[] szFeature)
    {
        this.WorkWithExt(FeatureNum(szFeature));
    }

    void WorkWithExt(int iFeature)
    {
        switch(iFeature)
        {
            case E_CPrefix: this.m_tpBuffer = this.m_tpCPrefix;
            case E_Prefix: this.m_tpBuffer = this.m_tpLPrefix;
            case E_CName: this.m_tpBuffer = this.m_tpCName;
            case E_CMessage: this.m_tpBuffer = this.m_tpCMessage;

            default: this.m_tpBuffer.ResetPart();
        }
    }

    void WriteValue(const char[] szKey)
    {
        this.m_tpBuffer.SetKey(szKey);
    }

    void WriteGroup()
    {
        this.m_tpBuffer.SetGroup(this.m_szVIPGroup);
    }

    void WriteFeature(const char[] szFeature)
    {
        this.m_tpBuffer.SetFeature(szFeature);
    }

    bool IsInvalidKey()
    {
        return this.m_tpBuffer.IsPartEmpty();
    }

    void WritePart(TemplatePart template)
    {
        this.m_tpBuffer = template;
    }

    void TransToValue(bool IsPrefix)
    {
        if(IsPrefix)
            Format(this.m_tpBuffer.m_szTranslationKey, PREFIX_LENGTH, "%t", this.m_tpBuffer.m_szTranslationKey);
        
        else aPalette.GetString(aPalette.FindString(this.m_tpBuffer.m_szTranslationKey)+1, this.m_tpBuffer.m_szTranslationKey, PREFIX_LENGTH);
    }

    void EndWork(const char[] szFeature)
    {
        switch(FeatureNum(szFeature))
        {
            case E_CPrefix: this.m_tpCPrefix = this.m_tpBuffer;
            case E_Prefix: this.m_tpLPrefix = this.m_tpBuffer;
            case E_CName: this.m_tpCName = this.m_tpBuffer;
            case E_CMessage: this.m_tpCMessage = this.m_tpBuffer;

            default: this.m_tpBuffer.ResetPart();
        }
    }

    void ResetTemplate()
    {
        this.m_tpCPrefix.ResetPart();
        this.m_tpLPrefix.ResetPart();
        this.m_tpCName.ResetPart();
        this.m_tpCMessage.ResetPart();
    }

    char GetGroup()
    {
        return this.m_szVIPGroup;
    }

    char SetGroup(const char[] szValue)
    {
        strcopy(this.m_szVIPGroup, strlen(szValue) + 1, szValue);
    }
}

ClientTemplate tempClient[MAXPLAYERS+1];


// static const char szCVars[][] = {"vip_prefix_pririty", "vip_name_priority", "vip_message_priority"};

#define CPREFIX_PRIO    "vip_cprefix_priority"
#define LPREFIX_PRIO    "vip_lprefix_priority"
#define CNAME_PRIO      "vip_cname_priority"
#define CMESSAGE_PRIO   "vip_cmessage_priority"


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

    aFeatureList = new ArrayList(MESSAGE_LENGTH, 0);

    CreateConVar(CPREFIX_PRIO, "2", "The priority level to change the color of the prefix", _, true, 0.0).AddChangeHook(ChangeCPrefix);
    CreateConVar(LPREFIX_PRIO, "2", "The priority level to change the value of prefix", _, true, 0.0).AddChangeHook(ChangeLPrefix);
    CreateConVar(CNAME_PRIO, "2", "The priority level to change the color of the username", _, true, 0.0).AddChangeHook(ChangeCName);
    CreateConVar(CMESSAGE_PRIO, "2", "The priority level to change the color of the usermessage", _, true, 0.0).AddChangeHook(ChangeCMessage);

    AutoExecConfig(true, "vip_chat", "ccprocessor");

    if(VIP_IsVIPLoaded())
        VIP_OnVIPLoaded(); 

    for(int i; i < sizeof(g_szFeatures); i++)
        coFeatures[i] = RegClientCookie(g_szFeatures[i], g_szFeatures[i], CookieAccess_Private);
}

_CVAR_ON_CHANGE(ChangeCPrefix)
{
    nLevel[E_CPrefix] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeLPrefix)
{
    nLevel[E_Prefix] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCName)
{
    nLevel[E_CName] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCMessage)
{
    nLevel[E_CMessage] = cvar.IntValue;
}

SMCParser smParser;

public void OnMapStart()
{
    _CVAR_INIT_CHANGE(ChangeCPrefix,    CPREFIX_PRIO);
    _CVAR_INIT_CHANGE(ChangeLPrefix,    LPREFIX_PRIO);
    _CVAR_INIT_CHANGE(ChangeCName,      CNAME_PRIO);
    _CVAR_INIT_CHANGE(ChangeCMessage,   CMESSAGE_PRIO);

    char path[PMP];
    BUILD(path, _CONFIG_PATH);
    
    if(!FileExists(path))
        SetFailState("Where is my config: %s ???", path);

    aFeatureList.Clear();

    smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;
    smParser.OnLeaveSection = OnLeave;
    smParser.OnEnd = OnParseEnded;

    int iLine;
    if(smParser.ParseFile(path, iLine) != SMCError_Okay)
        LogError("Failed on line: %i", iLine);
}

int Section;

ArrayList aGroups;

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(FeatureNum(name) != -1)
    {
        aFeatureList.PushString(name);
        
        if(!aGroups)
            aGroups = new ArrayList(128, 0);
    }
        
    Section++;

    return SMCParse_Continue;
}

SMCResult OnLeave(SMCParser smc)
{
    if(Section == 2)
        aFeatureList.Push(aGroups.Clone());

    aGroups.Clear();

    Section--;

    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;
    
    TemplatePart templatePart;

    aGroups.PushString(sKey);

    ArrayList aValues = new ArrayList(sizeof(templatePart), 0);

    char szBuffer[1024];
    strcopy(SZ(szBuffer), sValue);

    int i = -1, a;
    while(szBuffer[(++i)] != 0)
    {
        if(szBuffer[i] == ';' || szBuffer[i+1] == 0)
        {
            templatePart.m_szTranslationKey[a] = 0;

            aValues.PushArray(SZ(templatePart));

            templatePart.m_szTranslationKey = NULL_STRING;

            a = 0;

            continue;
        }

        templatePart.m_szTranslationKey[a] = szBuffer[i];
        a++;
    }

    templatePart.ResetPart();

    aGroups.Push(aValues.Clone());

    delete aValues;

    return SMCParse_Continue;
}

public void OnParseEnded(SMCParser smc, bool halted, bool failed)
{
    delete aGroups;

    if(blate)
        cc_config_parsed();
}

public void cc_config_parsed()
{
    DeleteSafly(aPalette);

    aPalette = cc_drop_palette();
}

public void VIP_OnVIPLoaded()
{
    for(int i; i < sizeof(g_szFeatures); i++)
        VIP_RegisterFeature(g_szFeatures[i], INT, SELECTABLE, OnSelected_Feature, OnDisplay_Feature);
}

public void OnPluginEnd()
{
    if(!CanTestFeatures() || GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") != FeatureStatus_Available)
        return;
    
    for(int i; i < sizeof(g_szFeatures); i++)
        VIP_UnregisterFeature(g_szFeatures[i]);
}

public bool OnSelected_Feature(int iClient, const char[] szFeature)
{
    bCustom[iClient] = false;

    Menu hMenu = FeatureMenu(iClient, szFeature);
    if(hMenu)   
        hMenu.Display(iClient, MENU_TIME_FOREVER);

    return false;
}

// Now prefix color is object

/*public int OnFeatureDraw(int iClient, const char[] szFeature, int iStyle)
{
    if(!strcmp(szFeature, g_szFeatures[E_CPrefix]))
    {
        if(tempClient.m_tpLPrefix.IsPartEmpty() || ColoredPrefix[iClient])
            return ITEMDRAW_DISABLED;
    }

    return iStyle;
}*/

public bool OnDisplay_Feature(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
    SetGlobalTransTarget(iClient);

    char szFValue[MESSAGE_LENGTH];
    tempClient[iClient].WorkWith(szFeature);

    strcopy(SZ(szFValue), tempClient[iClient].m_tpBuffer.GetKey());

    if(strcmp(szFeature, g_szFeatures[E_Prefix]))
    {
        aPalette.GetString(aPalette.FindString(szFValue)+1, SZ(szFValue));
        Format(SZ(szFValue), "%t", szFValue);
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
    tempClient[iClient].ResetTemplate();
    tempClient[iClient].SetGroup(NULL_STRING);
}

public void VIP_OnVIPClientLoaded(int iClient)
{
    VIP_GetClientVIPGroup(iClient, tempClient[iClient].m_szVIPGroup, sizeof(tempClient[].m_szVIPGroup));

    for(int i; i < sizeof(g_szFeatures); i++)
        if(VIP_IsClientFeatureUse(iClient, g_szFeatures[i]))
            GetValueFromCookie(iClient, coFeatures[i], g_szFeatures[i]);
}

void GetValueFromCookie(int iClient, Handle coHandle, const char[] szFeature)
{
    if(coHandle && coHandle != INVALID_HANDLE)
    {
        SetGlobalTransTarget(iClient);

        TemplatePart templatePart;

        char szBuffer[MESSAGE_LENGTH];
        GetClientCookie(iClient, coHandle, SZ(szBuffer));

        tempClient[iClient].WorkWith(szFeature);
        tempClient[iClient].WriteValue(szBuffer);
        tempClient[iClient].WriteGroup();
        tempClient[iClient].WriteFeature(szFeature);
        
        if(tempClient[iClient].IsInvalidKey())
        {
            tempClient[iClient].m_tpBuffer.ResetPart();
            return;
        }
        
        ArrayList aValues = GetGroupList(GetFeatureList(szFeature), tempClient[iClient].m_szVIPGroup);

        bool bFind;

        for(int i; i < aValues.Length; i++)
        {
            aValues.GetArray(i, SZ(templatePart));

            // FormatEx(szBuffer, sizeof(szBuffer), "%t", templatePart.m_szTranslationKey);

            if(!StrEqual(szFeature, g_szFeatures[E_Prefix]))
            {
                aPalette.GetString(aPalette.FindString(templatePart.m_szTranslationKey)+1, SZ(szBuffer));
            }

            else FormatEx(szBuffer, sizeof(szBuffer), "%t", templatePart.m_szTranslationKey);

            if(!UTF8StrEqual(tempClient[iClient].m_tpBuffer.m_szTranslationKey, szBuffer, false))
            {
                templatePart.ResetPart();
                continue;
            }

            tempClient[iClient].WritePart(templatePart);
            tempClient[iClient].TransToValue(StrEqual(szFeature, g_szFeatures[E_Prefix]));

            bFind = true;

            break;
        }

        if(bFind || FindTransKey(aValues, "custom") != -1)
        {
            tempClient[iClient].EndWork(szFeature);
            return;
        }

        else tempClient[iClient].m_tpBuffer.ResetPart();
    }
}

Menu FeatureMenu(int iClient, const char[] szFeature)
{
    Menu hMenu;
    char szBuffer[PMP];
    char szOpt[8];
    ArrayList aValues;
    TemplatePart templatePart;

    SetGlobalTransTarget(iClient);

    strcopy(ccl_current_feature[iClient], sizeof(ccl_current_feature[]), szFeature);
    
    aValues = GetGroupList(GetFeatureList(szFeature), tempClient[iClient].m_szVIPGroup);
        
    hMenu = new Menu(FeatureMenu_CallBack);

    FormatEx(SZ(szBuffer), "%s_title", szFeature);
    hMenu.SetTitle("%t \n \n", szBuffer);

    tempClient[iClient].WorkWith(szFeature);

    FormatEx(SZ(szBuffer), "%t \n \n", "disable_this");
    hMenu.AddItem("disable", szBuffer, (tempClient[iClient].IsInvalidKey()) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if(FindTransKey(aValues, "custom") != -1)
    {
        FormatEx(SZ(szBuffer), "%t \n \n", "custom");
        hMenu.AddItem("custom", szBuffer);
    }

    for(int i; i < aValues.Length; i++)
    {
        aValues.GetArray(i, SZ(templatePart));

        if(StrEqual(templatePart.m_szTranslationKey, "custom"))
        {
            templatePart.ResetPart();
            continue;
        }

        if(StrEqual(szFeature, g_szFeatures[E_Prefix]))
            aPalette.GetString(aPalette.FindString(templatePart.m_szTranslationKey)+2, SZ(szBuffer));
        
        Format(SZ(szBuffer), "%t", szBuffer);
        
        IntToString(i, SZ(szOpt));

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
            char szOpt2[8];
            hMenu.GetItem(iOpt2, SZ(szOpt2));

            if(szOpt2[0] == 'c')
            {
                bCustom[iClient] = true;

                PrintToChat(iClient, "%t", "ccp_custom_value");

                return;
            }

            TemplatePart templatePart;
            tempClient[iClient].WorkWith(ccl_current_feature[iClient]);

            tempClient[iClient].WritePart(templatePart);

            if(szOpt2[0] != 'd')
            {
                ArrayList aValues = GetGroupList(GetFeatureList(ccl_current_feature[iClient]), tempClient[iClient].m_szVIPGroup);
                aValues.GetArray(StringToInt(szOpt2), SZ(templatePart));

                tempClient[iClient].WritePart(templatePart);
                tempClient[iClient].TransToValue(StrEqual(ccl_current_feature[iClient], g_szFeatures[E_Prefix]));
            }

            SetClientCookie(iClient, coFeatures[FeatureNum(ccl_current_feature[iClient])], tempClient[iClient].m_tpBuffer.m_szTranslationKey);

            tempClient[iClient].EndWork(ccl_current_feature[iClient]);

            VIP_SendClientVIPMenu(iClient, true);
        }
    }
}

public Action OnClientSayCommand(int iClient, const char[] command, const char[] args)
{
    if(!IsClientInGame(iClient) || IsFakeClient(iClient) || IsChatTrigger())
        return Plugin_Continue;

    if(bCustom[iClient])
    {
        char szBuffer[PREFIX_LENGTH];

        tempClient[iClient].WorkWith(ccl_current_feature[iClient]);
        tempClient[iClient].WriteGroup();
        tempClient[iClient].WriteFeature(ccl_current_feature[iClient]);

        if(!StrEqual(ccl_current_feature[iClient], g_szFeatures[E_Prefix]))
        {
            int iPos;
            if((iPos = aPalette.FindString(args)) == -1)
            {
                PrintToChat(iClient, "%t", "ccp_invalid_colorkey");
                return Plugin_Handled;
            }

            aPalette.GetString(iPos+1, SZ(szBuffer));
        }

        else strcopy(SZ(szBuffer), args);
        
        tempClient[iClient].WriteValue(szBuffer);
        tempClient[iClient].EndWork(ccl_current_feature[iClient]);

        bCustom[iClient] = false;

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

int iMsgType;

public void cc_proc_MsgBroadType(const int iType)
{
    iMsgType = iType;
}

public void cc_proc_RebuildString(int iClient, int &plevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(iMsgType > eMsg_ALL || !VIP_IsClientVIP(iClient))
        return;
    
    static int i;
    i = (!strcmp(szBind, "{NAMECO}")) ? E_CName : (!strcmp(szBind, "{PREFIX}")) ? E_Prefix : (!strcmp(szBind, "{MSGCO}")) ? E_CMessage : (!strcmp(szBind, "{PREFIXCO}")) ? E_CPrefix : -1;

    if(i == -1)
        return;
    
    if(nLevel[i] < plevel)
        return;

    tempClient[iClient].WorkWithExt(i);
    if(tempClient[iClient].IsInvalidKey())
        return;
    
    plevel = nLevel[i];
                
    FormatEx(szBuffer, iSize, "%s", tempClient[iClient].m_tpBuffer.GetKey());

    tempClient[iClient].m_tpBuffer.ResetPart();
}

void DeleteSafly(Handle &hValue)
{
    // if we use `delete` on an already invalid descriptor, we will get an exception

    /*
        `delete` is equivalent to:

        if(handle != null)
            handle.Close()
        
        handle = null;
    */

    if(hValue == INVALID_HANDLE)
        hValue = null;
    
    delete hValue;
}

int FeatureNum(const char[] szFeature)
{
    for(int i; i < sizeof(g_szFeatures); i++)
        if(StrEqual(szFeature, g_szFeatures[i]))
            return i;

    return -1;
}

ArrayList GetFeatureList(const char[] szFeature)
{
    return view_as<ArrayList>(aFeatureList.Get(aFeatureList.FindString(szFeature)+1));
}

ArrayList GetGroupList(ArrayList inputList, const char[] szGroup)
{
    return view_as<ArrayList>(inputList.Get(inputList.FindString(szGroup)+1));
}

int FindTransKey(ArrayList inputList, const char[] key)
{
    TemplatePart templatePart;

    for(int i; i < inputList.Length; i++)
    {
        aFeatureList.GetArray(i, SZ(templatePart));

        if(StrEqual(templatePart.m_szTranslationKey, key))
            return i;
        
        templatePart.ResetPart();
    }

    return -1;
}
