#pragma newdecls required

#include <ccprocessor>

static char g_szLogEx[MESSAGE_LENGTH] = "logs/ccprocessor"

UserMessageType umType;

ArrayList 
    aPalette,
    netMessage;

char 
    msgPrototype[eMsg_MAX][MESSAGE_LENGTH];

ConVar game_mode;

char mode_default_value[8];

GlobalForward
    g_fwdSkipColors,
    g_fwdRebuildString,
    g_fwdOnDefMessage,
    g_fwdConfigParsed,
    g_fwdMessageType,
    g_fwdOnMsgBuilt,
    g_fwdIdxApproval,
    g_fwdRestrictRadio,
    g_fwdAPIHandShake;

bool g_bRTP, g_bDBG;

public Plugin myinfo = 
{
    name        = "CCProcessor",
    author      = "nullent?",
    description = "Color chat processor",
    version     = "2.5.4",
    url         = "discord.gg/ChTyPUG"
};

#define SZ(%0) %0, sizeof(%0)

enum 
{
    eIdx = 0,
    eMsg,
    eArray,
    eCount,
    eAny
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{    
    umType = GetUserMessageType();

    HookUserMessage(GetUserMessageId("TextMsg"), UserMessage_TextMsg, true);
    HookUserMessage(GetUserMessageId("SayText"), UserMessage_SayText, true);
    HookUserMessage(GetUserMessageId("SayText2"), UserMessage_SayText2, true, SayText2_Completed);
    HookUserMessage(GetUserMessageId("RadioText"), UserMessage_RadioText, true, RadioText_Completed);

    CreateNative("cc_drop_palette", Native_DropPalette);
    CreateNative("cc_clear_allcolors", Native_ClearAllColors);
    CreateNative("cc_get_APIKey", Native_GetAPIKey);
    CreateNative("cc_is_APIEqual", Native_IsAPIEqual);

    g_fwdSkipColors     = new GlobalForward("cc_proc_SkipColorsInMsg", ET_Hook, Param_Cell);
    g_fwdRebuildString  = new GlobalForward("cc_proc_RebuildString", ET_Ignore, Param_Cell, Param_CellByRef, Param_String, Param_String, Param_Cell);
    g_fwdOnDefMessage   = new GlobalForward("cc_proc_OnDefMsg", ET_Hook, Param_String, Param_Cell, Param_Cell);
    g_fwdConfigParsed   = new GlobalForward("cc_config_parsed", ET_Ignore);
    g_fwdMessageType    = new GlobalForward("cc_proc_MsgBroadType", ET_Ignore, Param_Cell);
    g_fwdOnMsgBuilt     = new GlobalForward("cc_proc_OnMessageBuilt", ET_Ignore, Param_Cell, Param_String);
    g_fwdIdxApproval    = new GlobalForward("cc_proc_IndexApproval", ET_Ignore, Param_CellByRef);
    g_fwdRestrictRadio  = new GlobalForward("cc_proc_RestrictRadio", ET_Hook, Param_Cell, Param_String);
    g_fwdAPIHandShake   = new GlobalForward("cc_proc_APIHandShake", ET_Ignore, Param_String);

    RegPluginLibrary("ccprocessor");

    return APLRes_Success;
}

#include "ccprocessor/ccp_saytext2.sp"
#include "ccprocessor/ccp_saytext.sp"
#include "ccprocessor/ccp_textmsg.sp"
#include "ccprocessor/ccp_radiomsg.sp"

public void OnPluginStart()
{
    LoadTranslations("ccproc.phrases");
    LoadTranslations("ccp_defmessage.phrases");

    aPalette = new ArrayList(PREFIX_LENGTH, 0);
    netMessage = new ArrayList(MAX_LENGTH, 0);

    {
        if(!DirExists("/cfg/ccprocessor"))
            CreateDirectory("/cfg/ccprocessor", 0x1ED);
    
        BuildPath(Path_SM, g_szLogEx, sizeof(g_szLogEx), g_szLogEx);

        if(!DirExists(g_szLogEx))
            CreateDirectory(g_szLogEx, 0x1ED);

        Format(g_szLogEx, sizeof(g_szLogEx), "%s/logging.log", g_szLogEx);
    }
    
    CreateConVar("ccp_color_RTP", "0", "Enable/Disable color real time processing", _, true, 0.0, true, 1.0).AddChangeHook(CCP_RTP);
    CreateConVar("ccp_debug_mode", "0", "Enable/Disable debug mode", _, true, 0.0, true, 1.0).AddChangeHook(CCP_DBG);

    AutoExecConfig(true, "core", "ccprocessor");

    game_mode = FindConVar("game_mode");
    if(!game_mode)
    {
        LogMessage("Could not find handle for 'game_mode' cvar");
        return;
    }

    game_mode.AddChangeHook(OnModChanged);
    game_mode.GetString(mode_default_value, sizeof(mode_default_value));
}

public void OnAllPluginsLoaded()
{
    Call_StartForward(g_fwdAPIHandShake);
    Call_PushString(API_KEY);
    Call_Finish();
}

public void OnModChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    cvar.GetString(mode_default_value, sizeof(mode_default_value));
}

public void CCP_RTP(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    g_bRTP = cvar.BoolValue;
}

public void CCP_DBG(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    g_bDBG = cvar.BoolValue;
}

public void OnMapStart()
{
    CCP_RTP(FindConVar("ccp_color_RTP"), NULL_STRING, NULL_STRING);
    CCP_DBG(FindConVar("ccp_debug_mode"), NULL_STRING, NULL_STRING);

#define SETTINGS_PATH "configs/c_var/%s.ini"

    static char szConfig[MESSAGE_LENGTH];

    if(!szConfig[0])
    {
        GetGameFolderName(SZ(szConfig));
        Format(SZ(szConfig), SETTINGS_PATH, szConfig);

        BuildPath(Path_SM, SZ(szConfig), szConfig);
    }

    if(!FileExists(szConfig))
        SetFailState("Where is my config: %s ", szConfig);

    aPalette.Clear();
    
    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnKeyValue;
    smParser.OnEnterSection = OnEnterSection;
    smParser.OnEnd = OnCompReading;
    smParser.OnLeaveSection = OnLeave;

    int iLine;
    if(smParser.ParseFile(szConfig, iLine) != SMCError_Okay)
        LogError("An error was detected on line '%i' while reading", iLine);
    
    LOG_WRITE("OnMapStart(): Config: %s, Pallete array: %x, Parser: %x", szConfig, aPalette, smParser);
}

public void OnConfigsExecuted()
{
    if(game_mode)
        game_mode.Flags |= FCVAR_REPLICATED;
}

public void BackMode(any data)
{
    if(game_mode)
        game_mode.ReplicateToClient(data, mode_default_value);
}

int Section;

SMCResult OnEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    // main ++ > 1 Palette ++ > 2 Key
    if(Section > 1)
    {
        aPalette.PushString(name);

        LOG_WRITE("OnEnterSection(): %s", name);
    }
        
    Section++;

    return SMCParse_Continue;
}

SMCResult OnLeave(SMCParser smc)
{
    Section--;

    return SMCParse_Continue;
}

SMCResult OnKeyValue(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    int iBuffer;

    if(!strcmp(sKey, "value"))
    {
        char szExplode[2][PREFIX_LENGTH];
        ExplodeString(sValue, ";", SZ(szExplode), sizeof(szExplode[]));

        iBuffer = strlen(szExplode[0]);

        switch(iBuffer)
        {
            // Defined ASCII colors
            case 1, 2: Format(szExplode[0], sizeof(szExplode[]), "%c", StringToInt(szExplode[0]));

            // Colors based RGB/RGBA into HEX format: #RRGGBB/#RRGGBBAA
            case 7, 9: FormatEx(szExplode[0], sizeof(szExplode[]), "%c%s", (iBuffer == 7) ? 7 : 8, szExplode[0][1]);

            default: LogError("Invalid color length for value: %s", szExplode[0]);
        }

        aPalette.PushString(szExplode[0]);
        aPalette.PushString(szExplode[1]);

        LOG_WRITE("OnKeyValue(): ReadKey: %s, Value[0]: %s, Value[1]: %s", sKey, szExplode[0], szExplode[1]);
    }

    else
    {
        iBuffer =   (!strcmp(sKey, "Chat_PrototypeTeam"))   ? eMsg_TEAM : 
                    (!strcmp(sKey, "Chat_PrototypeAll"))    ? eMsg_ALL : 
                    (!strcmp(sKey, "Changename_Prototype")) ? eMsg_CNAME : 
                    (!strcmp(sKey, "Chat_ServerTemplate"))  ? eMsg_SERVER :
                    (!strcmp(sKey, "Chat_RadioText"))       ? eMsg_RADIO : -1;
        
        if(iBuffer != -1)
            strcopy(msgPrototype[iBuffer], sizeof(msgPrototype[]), sValue);

        LOG_WRITE("OnKeyValue(): ReadKey: %s, Value: %s", sKey, sValue);
    }

    return SMCParse_Continue;
}

public void OnCompReading(SMCParser smc, bool halted, bool failed)
{
    if(smc == INVALID_HANDLE)
        smc = null;

    delete smc;

    Call_OnCompReading();

    if(halted || failed)
        SetFailState("There was a problem reading the configuration file");
}

void ReplaceColors(char[] szBuffer, int iSize, bool bToNullStr)
{
    static char szKey[STATUS_LENGTH], szColor[STATUS_LENGTH];
    szColor = "";
    szKey   = "";

    int a;

    // aPalette:> Key:Value:Transl
    for(int i; i < aPalette.Length; i++)
    {
        if(++a == 3)
        {
            a = 0;
            continue;
        }

        if(a%2 == 1 || bToNullStr)
        {
            aPalette.GetString(i, SZ(szKey));

            if(!bToNullStr)
                continue;
        }
            
        if(!bToNullStr) aPalette.GetString(i, SZ(szColor));

        ReplaceString(szBuffer, iSize, szKey, szColor, true);
    }
}

// Available keys:
//  {PROTOTYPE}, {STATUS}, {TEAM}, {PREFIXCO}, {PREFIX}, {NAMECO}, {NAME}, {MSGCO}, {MSG}

void GetMessageByPrototype(
    int iIndex, int iType, int iTeam, bool IsAlive, char[] szName, int NameSize, char[] szMessage, int MsgSize, char[] szBuffer, int iSize
)
{
    static char Other[MESSAGE_LENGTH];
    Other = NULL_STRING;

    Call_MessageBroadType(iType);

    FormatEx(szBuffer, iSize, msgPrototype[iType]);
    
    LOG_WRITE("GetMessageByPrototype(): prototype before call: %s", szBuffer);

    Call_RebuildString(iIndex, "{PROTOTYPE}", szBuffer, iSize);

    LOG_WRITE("GetMessageByPrototype(): prototype after call: %s", szBuffer);

    if(!szBuffer[0])
        return;

    Format(szBuffer, iSize, "%c %s", 1, szBuffer);
    
    if(StrContains(szBuffer, "{STATUS}") != -1)
    {
        FormatEx(SZ(Other), "%T", (IsAlive) ? "ClientStatus_Alive" : "ClientStatus_Died", LANG_SERVER);

        Call_RebuildString(iIndex, "{STATUS}", SZ(Other));

        LOG_WRITE("GetMessageByPrototype(): {STATUS} after call: %s", Other);

        BreakPoint(Other, STATUS_LENGTH);
        ReplaceString(szBuffer, iSize, "{STATUS}", Other, true);
    }

    if(StrContains(szBuffer, "{TEAM}") != -1 && iType != eMsg_CNAME)
    {
        GetTeamPhrase(LANG_SERVER, iTeam, iType, SZ(Other));
        
        Call_RebuildString(iIndex, "{TEAM}", SZ(Other));

        LOG_WRITE("GetMessageByPrototype(): {TEAM} after call: %s", Other);

        BreakPoint(Other, TEAM_LENGTH);
        ReplaceString(szBuffer, iSize, "{TEAM}", Other, true);
    }

    // This isn't the best solution, but so far everything is in order.... i think.
    if(StrContains(szBuffer, "{PREFIXCO}") != -1)
    {
        Other = NULL_STRING;

        Call_RebuildString(iIndex, "{PREFIXCO}", SZ(Other));

        LOG_WRITE("GetMessageByPrototype(): {PREFIXCO} after call: %s", Other);

        BreakPoint(Other, STATUS_LENGTH);        
        ReplaceString(szBuffer, iSize, "{PREFIXCO}", Other, true);
    }

    if(StrContains(szBuffer, "{PREFIX}") != -1)
    {
        Other = NULL_STRING;

        Call_RebuildString(iIndex, "{PREFIX}", SZ(Other));

        LOG_WRITE("GetMessageByPrototype(): {PREFIX} after call: %s", Other);

        BreakPoint(Other, PREFIX_LENGTH);        
        ReplaceString(szBuffer, iSize, "{PREFIX}", Other, true);
    }

    if(StrContains(szBuffer, "{NAMECO}") != -1)
    {
        FormatEx(SZ(Other), "%c", 3);
        Call_RebuildString(iIndex, "{NAMECO}", SZ(Other));

        LOG_WRITE("GetMessageByPrototype(): {NAMECO} after call: %s", Other);

        BreakPoint(Other, STATUS_LENGTH);        
        ReplaceString(szBuffer, iSize, "{NAMECO}", Other, true);
    }

    if(StrContains(szBuffer, "{NAME}") != -1)
    {
        Call_RebuildString(iIndex, "{NAME}", szName, NameSize);

        LOG_WRITE("GetMessageByPrototype(): {NAME} after call: %s", szName);

        ReplaceString(szBuffer, iSize, "{NAME}", szName, true);
    }

    if(StrContains(szBuffer, "{MSGCO}") != -1)
    {
        FormatEx(SZ(Other), "%c", 1);
        Call_RebuildString(iIndex, "{MSGCO}", SZ(Other));

        LOG_WRITE("GetMessageByPrototype(): {MSGCO} after call: %s", Other);

        BreakPoint(Other, STATUS_LENGTH);        
        ReplaceString(szBuffer, iSize, "{MSGCO}", Other, true);
    }

    if(StrContains(szBuffer, "{MSG}") != -1 && iType != eMsg_RADIO)
    {
        Call_RebuildString(iIndex, "{MSG}", szMessage, MsgSize);
        TrimString(szMessage);

        LOG_WRITE("GetMessageByPrototype(): {MSG} after call: %s", szMessage);

        ReplaceString(szBuffer, iSize, "{MSG}", szMessage, true);
    }

    LOG_WRITE("GetMessageByPrototype(): Message after build: %s", szBuffer);
}

void BreakPoint(char[] szValue, int MaxLength)
{
    if(strlen(szValue) >= MaxLength)
        szValue[MaxLength] = 0;
}

void GetTeamPhrase(int iLangI, int iTeam, int iType, char[] szBuffer, int size)
{
    szBuffer[0] = '\0';

    if(iType == eMsg_CNAME || iTeam == eMsg_SERVER)
        return;
    
    if(iType == eMsg_RADIO)
        FormatEx(szBuffer, size, "%T", "RadioMsg", iLangI);
    
    else
    {
        switch(iTeam)
        {
            case 1: FormatEx(szBuffer, size, "%T", (iType) ? "TeamSPECAll"  : "TeamSPEC",   iLangI);
            case 2: FormatEx(szBuffer, size, "%T", (iType) ? "TeamTAll"     : "TeamT",      iLangI);
            case 3: FormatEx(szBuffer, size, "%T", (iType) ? "TeamCTAll"    : "TeamCT",     iLangI);
            default: return;
        }
    }
}

void LOG_WRITE(const char[] szMessage, any ...)
{
    if(!g_bDBG)
        return;
    
    static char szBuffer[1024];

    VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);

    LogToFileEx(g_szLogEx, szMessage);
}

public int Native_ClearAllColors(Handle hPlugin, int iArgs)
{
    char szBuffer[MESSAGE_LENGTH];
    GetNativeString(1, SZ(szBuffer));

    ReplaceColors(SZ(szBuffer), true);

    SetNativeString(1, SZ(szBuffer));
}

public int Native_GetAPIKey(Handle hPlugin, int iArgs)
{
    char szBuffer[PREFIX_LENGTH];
    GetNativeString(1, SZ(szBuffer));

    strcopy(SZ(szBuffer), API_KEY);

    SetNativeString(1, SZ(szBuffer));
}

public int Native_IsAPIEqual(Handle hPlugin, int iArgs)
{
    char szBuffer[PREFIX_LENGTH];
    GetNativeString(1, SZ(szBuffer));

    return StrEqual(szBuffer, API_KEY, true);
}

public int Native_DropPalette(Handle hPlugins, int iArgs)
{
    return view_as<int>(aPalette.Clone());
}

void Call_OnCompReading()
{
    Call_StartForward(g_fwdConfigParsed);
    Call_Finish();
}

void Call_RebuildString(int iClient, const char[] szBind, char[] szMessage, int iSize)
{
    LOG_WRITE("Call_RebuildString(): %i, %s, %s, %i", iClient, szBind, szMessage, iSize);

    int plevel;
    Call_StartForward(g_fwdRebuildString);
    Call_PushCell(iClient);
    Call_PushCellRef(plevel);
    Call_PushString(szBind);
    Call_PushStringEx(szMessage, iSize, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iSize);
    Call_Finish();
}

Action Call_OnDefMessage(const char[] szMessage, bool IsPhraseExists, bool IsTranslated)
{
    Action Send = (IsTranslated && IsPhraseExists) ? Plugin_Changed : Plugin_Continue;

    Call_StartForward(g_fwdOnDefMessage);
    Call_PushString(szMessage);
    Call_PushCell(IsPhraseExists);
    Call_PushCell(IsTranslated);

    Call_Finish(Send);

    LOG_WRITE("Call_OnDefMessage(): %s, %b, %b, result: %d", szMessage, IsPhraseExists, IsTranslated, Send);

    return Send;
}

bool Call_IsSkipColors(int iClient)
{
    bool skip = g_bRTP;

    Call_StartForward(g_fwdSkipColors);
    Call_PushCell(iClient);
    Call_Finish(skip);

    LOG_WRITE("Call_IsSkipColors(): %i, %b", iClient, skip);

    return skip;
}

void Call_MessageBroadType(const int iType)
{
    LOG_WRITE("Call_MessageBroadType(): %i", iType);

    Call_StartForward(g_fwdMessageType);
    Call_PushCell(iType);
    Call_Finish();
}

void Call_IndexApproval(int &iIndex)
{
    int back = iIndex;

    Call_StartForward(g_fwdIdxApproval);
    Call_PushCellRef(iIndex);
    Call_Finish();

    if(iIndex < 1)
        iIndex = back;

    LOG_WRITE("Call_IndexApproval(): %i, %i", iIndex, back);
}

void Call_MessageBuilt(int iIndex, const char[] BuiltMessage)
{
    LOG_WRITE("Call_MessageBuilt(): %i, %s", iIndex, BuiltMessage);

    Call_StartForward(g_fwdOnMsgBuilt);
    Call_PushCell(iIndex);
    Call_PushString(BuiltMessage)
    Call_Finish();
}

bool Call_RestrictRadioKey(int iIndex, const char[] szKey)
{
    bool restrict;

    Call_StartForward(g_fwdRestrictRadio);
    Call_PushCell(iIndex);
    Call_PushString(szKey)
    Call_Finish(restrict);

    return restrict;
}