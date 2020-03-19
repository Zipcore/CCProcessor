
#pragma newdecls required

#define STANDART_INFO

#define PlugName "CCLProcessor"
#define PlugDesc "Extended color chat processor"
#define PlugVer "1.0.7 Beta"

#include std

#define SETTINGS_PATH "configs/c_var/%s.ini"

//EngineVersion eEngine;

/* CSGO: Proto - SayText2, CSS OB: BF - SayText2 */
UserMessageType umType;

/* Key:Color */
ArrayList aTriggers;

/* Key:Translation */
ArrayList aPhrases;

char szGameFolder[PMP];
char msgPrototype[2][64];

ArrayList dClient;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{    
    //eEngine = GetEngineVersion();

    umType = GetUserMessageType();

    HookUserMessage(GetUserMessageId("TextMsg"), ServerMsg_CB, true);
    HookUserMessage(GetUserMessageId("SayText2"), MsgText_CB, true, SayTextComp);

    CreateNative("ccl_drop_list", Native_DropTriggers);
    CreateNative("ccl_clear_allcolors", Native_ClearAllColors);

    RegPluginLibrary("ccl_proc");

    return APLRes_Success;
}

public void OnPluginStart()
{
    GetGameFolderName(SZ(szGameFolder));
    LoadTranslations("cclproc.phrases");

    aTriggers = new ArrayList(64, 0);
    aPhrases = new ArrayList(64, 0);

    dClient = new ArrayList(512, 0);
}

public void OnMapStart()
{
    char szPath[PMP];
    FormatEx(SZ(szPath), SETTINGS_PATH, szGameFolder);

    BUILD(szPath, szPath);

    ReadConfig(szPath);
}

// 0 - Global, 1 - Triggers, 2 - Phrases
int Section;

void ReadConfig(const char[] szPath)
{
    aTriggers.Clear();

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;
    smParser.OnEnd = OnParseEnded;

    if(!FileExists(szPath))
        SetFailState("Where is my config??");
    
    int iLine;

    if(smParser.ParseFile(szPath, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %d", szPath, iLine);
}

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if(!strcmp(name, "Triggers"))
        Section = 1;
    
    else if(!strcmp(name, "Phrases"))
        Section = 2;
    
    else Section = 0;
    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    switch(Section)
    {
        case 1:
        {
            char szBuffer[16];

            aTriggers.PushString(sKey);

            if(strlen(sValue) > 3)
                FormatEx(SZ(szBuffer), "\x07%s", sValue);
            else
                FormatEx(SZ(szBuffer), "%c", StringToInt(sValue));

            aTriggers.PushString(szBuffer);
        }

        case 2:
        {
            if(aTriggers.FindString(sKey) == -1)
                return SMCParse_Continue;

            aPhrases.PushString(sKey);
            aPhrases.PushString(sValue);
        }

        default: strcopy(msgPrototype[strcmp(sKey, "Chat_PrototypeTeam") != 0], sizeof(msgPrototype[]), sValue);
    }

    return SMCParse_Continue;
}

public void OnParseEnded(SMCParser smc, bool halted, bool failed)
{
    if(halted || failed)
    {
        LogError("Parse failed");
        return;
    }

    clPoc_ParseEnded();
}

public Action ServerMsg_CB(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    static int Msg_type;

    /* 0 - ? | 1 - Console | 2 - Console | 3 - Chat | 4 - Hint | 5 - ?*/
    Msg_type = (!umType) ? BfReadByte(msg) : PbReadInt(msg, "msg_dst");
    if(Msg_type != 3)
        return Plugin_Continue;

    char szBuffer[PMP];

    if(!umType) BfReadString(msg, SZ(szBuffer));
    else PbReadString(msg, "params", SZ(szBuffer), 0);

    if(!clProc_ServerMsg(SZ(szBuffer)) || strlen(szBuffer) == 0)
        return Plugin_Handled;
    
    clProc_Replace(SZ(szBuffer));
    
    Format(SZ(szBuffer), "%c %s", 1, szBuffer);

    if(umType)
    {
        PbSetString(msg, "params", szBuffer, 0);
        return Plugin_Continue;
    }

    ArrayList arr = new ArrayList(PMP, 0);
    arr.Push(Msg_type);
    arr.PushString(szBuffer);
    arr.PushArray(players, playersNum);
    arr.Push(playersNum);
    RequestFrame(OnFrRequest, arr);
    
    return Plugin_Handled;
}

public void OnFrRequest(any data)
{
    char szMessage[PMP];
    view_as<ArrayList>(data).GetString(1, SZ(szMessage));

    int[] players = new int[view_as<ArrayList>(data).Get(3)];
    view_as<ArrayList>(data).GetArray(2, players, view_as<ArrayList>(data).Get(3));

    BfWrite rewriteB = UserMessageToBfWrite(StartMessage("TextMsg", players, view_as<ArrayList>(data).Get(3), USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
    rewriteB.WriteByte(view_as<ArrayList>(data).Get(0));
    rewriteB.WriteString(szMessage);
    rewriteB.WriteString(NULL_STRING);
    EndMessage();
}

public Action MsgText_CB(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    /**
     ** param 1: name
     ** param 2: msg
     ** param 3: pos
     ** param 4: \n
     **
     **/

    char szName[MNL];
    char szMessage[PMP];
    int iIndex;

    char szBuffer[448];
    bool ToAll;

    iIndex = (!umType) ? BfReadByte(msg) : PbReadInt(msg, "ent_idx");
    if(iIndex < 1 || !IsClientInGame(iIndex) || IsClientSourceTV(iIndex))
        return Plugin_Continue;

    if(!umType)
    {        
        BfReadByte(msg);
        BfReadString(msg, SZ(szName));
    }
    else PbReadString(msg, "msg_name", SZ(szName));

    if(StrContains(szName, "Cstrike_Name_Change") != -1)
        return clProc_BroadcastMessage();

    ToAll = (!umType) ? StrContains(szName, "_All") != -1 : PbReadBool(msg, "textallchat");

    if(!umType)
    {
        BfReadString(msg, SZ(szName));
        BfReadString(msg, SZ(szMessage));
    }
    else
    {
        PbReadString(msg, "params", SZ(szName), 0);
        PbReadString(msg, "params", SZ(szMessage), 1);
    }

    clProc_ClearColors(SZ(szName));
    if(!clProc_SkipColors(iIndex))
        clProc_ClearColors(SZ(szMessage));

    GetMessageByPrototype(iIndex, GetClientTeam(iIndex), (iIndex) ? IsPlayerAlive(iIndex) : false, ToAll, SZ(szName), SZ(szMessage), SZ(szBuffer));
    
    TrimString(szMessage);
    if(!szMessage[0])
        return Plugin_Handled;
        
    clProc_Replace(SZ(szBuffer));

    if(umType)
    {
        PbSetInt(msg, "ent_idx", iIndex);
        PbSetString(msg, "msg_name", szBuffer);

        return Plugin_Continue;
    }

    dClient.Push(iIndex);
    dClient.PushString(szBuffer);
    dClient.PushArray(players, playersNum);
    dClient.Push(playersNum);

    return Plugin_Handled;
}

public void SayTextComp(UserMsg msgid, bool send)
{
    if(send && umType == UM_BitBuf && dClient.Length)
    {
        char szMessage[512];
        dClient.GetString(1, SZ(szMessage));

        int[] players = new int[dClient.Get(3)];
        dClient.GetArray(2, players, dClient.Get(3));

        BfWrite bf = UserMessageToBfWrite(StartMessage("SayText2", players, dClient.Get(3), USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
        bf.WriteByte(dClient.Get(0));
        bf.WriteByte(1);
        bf.WriteString(szMessage);
        EndMessage();

        dClient.Clear();
    }
}


void clProc_Replace(char[] szBuffer, int iSize)
{
    static char szTrigger[64];
    static char szColors[16];

    for(int i; i < aTriggers.Length; i+=2)
    {
        aTriggers.GetString(i, SZ(szTrigger));
        aTriggers.GetString(i+1, SZ(szColors));

        ReplaceString(szBuffer, iSize, szTrigger, szColors, true);
    }
}

void clProc_ClearColors(char[] szBuffer, int iLen)
{
    static char szColor[64];
    for(int i; i < aTriggers.Length; i++)
    {
        aTriggers.GetString(i, SZ(szColor));
        ReplaceString(szBuffer, iLen, szColor, "", true);
    }
}

void GetMessageByPrototype(int iIndex, int iTeam, bool IsAlive, bool ToAll, char[] szName, int NameSize, char[] szMesage, int MsgSize, char[] szBuffer, int iSize)
{
    static char Other[MNL];

    SetGlobalTransTarget(iIndex);

    szBuffer[0] = 1;
    //LogMessage("inProt: %s", szBuffer);
    Other = "";

    Format(szBuffer, iSize, "%s %s", szBuffer, msgPrototype[view_as<int>(ToAll)]);
    
    if(StrContains(szBuffer, "{STATUS}") != -1)
    {
        if(iIndex)
            FormatEx(SZ(Other), "%t", (IsAlive) ? "ClientStatus_Alive" : "ClientStatus_Died");
        
        clProc_RebuildString(iIndex, "{STATUS}", SZ(Other));        
        ReplaceString(szBuffer, iSize, "{STATUS}", Other, true);
    }

    if(StrContains(szBuffer, "{TEAM}") != -1)
    {
        if(iIndex)
            FormatEx(
                SZ(Other), "%t", 
                (iTeam == 1 && ToAll) ? "TeamSPECAll" : 
                (iTeam == 1 && !ToAll) ? "TeamSPEC" :
                (iTeam == 2 && ToAll) ? "TeamTAll" :
                (iTeam == 2 && !ToAll) ? "TeamT" :
                (iTeam == 3 && ToAll) ? "TeamCTAll" :
                "TeamCT"
            );
        
        clProc_RebuildString(iIndex, "{TEAM}", SZ(Other));
        ReplaceString(szBuffer, iSize, "{TEAM}", Other, true);
    }

    if(StrContains(szBuffer, "{NAME}") != -1)
    {
        clProc_RebuildString(iIndex, "{NAME}", szName, NameSize);
        ReplaceString(szBuffer, iSize, "{NAME}", szName, true);
    }
        
    if(StrContains(szBuffer, "{MSG}") != -1)
    {
        clProc_RebuildString(iIndex, "{MSG}", szMesage, MsgSize);
        TrimString(szMesage);

        if(szMesage[0])
            ReplaceString(szBuffer, iSize, "{MSG}", szMesage, true);
    }
        
}

public int Native_ClearAllColors(Handle hPlugin, int iArgs)
{
    char szBuffer[PMP];
    GetNativeString(1, SZ(szBuffer));

    clProc_ClearColors(SZ(szBuffer));

    SetNativeString(1, SZ(szBuffer));
}

public int Native_DropTriggers(Handle hPlugins, int iArgs)
{
    return view_as<int>(GetNativeCell(1) == 0 ? aTriggers.Clone() : aPhrases.Clone());
}

void clPoc_ParseEnded()
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("ccl_config_parsed", ET_Ignore);
    
    Call_StartForward(gf);
    Call_Finish();
}

void clProc_RebuildString(int iClient, const char[] szBind, char[] szMessage, int iSize)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("ccl_proc_RebuildString", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
    
    Call_StartForward(gf);
    Call_PushCell(iClient);
    Call_PushString(szBind);
    Call_PushStringEx(szMessage, iSize, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iSize);
    Call_Finish();
}

bool clProc_ServerMsg(char[] szMessage, int iSize)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("ccl_proc_OnServerMsg", ET_Hook, Param_String, Param_Cell);
    
    bool Send = true;
    Call_StartForward(gf);
    Call_PushStringEx(szMessage, iSize, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iSize);
    Call_Finish(Send);

    return Send;
}

bool clProc_SkipColors(int iClient)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("ccl_proc_SkipColorsInMsg", ET_Hook, Param_Cell);
    
    bool skip = false;
    Call_StartForward(gf);
    Call_PushCell(iClient);
    Call_Finish(skip);

    return skip;
}

Action clProc_BroadcastMessage()
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("ccl_proc_OnUsernameChangedMsg", ET_Hook);
    
    Action aDo = Plugin_Continue;
    Call_StartForward(gf);
    Call_Finish(aDo);

    return aDo;
}