#pragma newdecls required

#define PROTO_COUNT     3
#define SETTINGS_PATH "configs/c_var/%s.ini"
#define SZ(%0) %0, sizeof(%0)

#include ccprocessor

UserMessageType umType;

ArrayList 
    aTriggers,
    aPhrases,
    netMessage;

char 
    szConfigPath[MESSAGE_LENGTH],
    msgPrototype[PROTO_COUNT][MESSAGE_LENGTH];

ConVar game_mode;

char mode_default_value[8];

public Plugin myinfo = 
{
    name        = "CCProcessor",
    author      = "nullent?",
    description = "Color chat processor",
    version     = "1.7.1",
    url         = "discord.gg/ChTyPUG"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{    
    umType = GetUserMessageType();

    HookUserMessage(GetUserMessageId("TextMsg"), ServerMsg_CB, true);
    HookUserMessage(GetUserMessageId("SayText2"), MsgText_CB, true, SayTextComp);

    CreateNative("cc_drop_list", Native_DropTriggers);
    CreateNative("cc_clear_allcolors", Native_ClearAllColors);

    RegPluginLibrary("ccprocessor");

    return APLRes_Success;
}

public void OnPluginStart()
{
    GetGameFolderName(SZ(szConfigPath));
    Format(SZ(szConfigPath), SETTINGS_PATH, szConfigPath);

    BuildPath(Path_SM, SZ(szConfigPath), szConfigPath);

    LoadTranslations("ccproc.phrases");

    aTriggers = new ArrayList(STATUS_LENGTH, 0);
    aPhrases = new ArrayList(TEAM_LENGTH, 0);
    netMessage = new ArrayList(MAX_LENGTH, 0);

    if(!DirExists("/cfg/ccprocessor"))
        CreateDirectory("/cfg/ccprocessor", 0x1ED);

    game_mode = FindConVar("game_mode");
    if(!game_mode)
    {
        LogError("Could not find handle for 'game_mode' cvar");
        return;
    }

    game_mode.AddChangeHook(OnModChanged);
    game_mode.GetString(mode_default_value, sizeof(mode_default_value));
}

public void OnModChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    cvar.GetString(mode_default_value, sizeof(mode_default_value));
}

public void OnMapStart()
{
    aTriggers.Clear();

    if(!FileExists(szConfigPath))
        SetFailState("Where is my config: %s ???", szConfigPath);
    
    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;
    smParser.OnEnterSection = OnSection;
    smParser.OnEnd = OnParseEnded;

    int iLine;

    if(smParser.ParseFile(szConfigPath, iLine) != SMCError_Okay)
        LogError("Fail on line '%i' when parse config file", iLine);
}

public void OnConfigsExecuted()
{
    if(game_mode)
        game_mode.Flags |= FCVAR_REPLICATED;
}

int Section;

SMCResult OnSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    Section = 
        (!strcmp(name, "Triggers")) ? 1 : 
        (!strcmp(name, "Phrases")) ? 2 : 0;

    return SMCParse_Continue;
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    static int ColorLen;
    static char szBuffer[STATUS_LENGTH];

    if(Section == 1)
    {
        szBuffer = NULL_STRING;

        aTriggers.PushString(sKey);

        ColorLen = strlen(sValue);

        switch(ColorLen)
        {
            // Defined ASCII colors
            case 1, 2: FormatEx(SZ(szBuffer), "%c", StringToInt(sValue));

            // Colors based RGB/RGBA into HEX format: #RRGGBB/#RRGGBBAA
            case 7, 9: FormatEx(SZ(szBuffer), "%c%s", (ColorLen == 7) ? 7 : 8, sValue[1]);

            default: LogError("Invalid color length '%i' for value: %s", ColorLen, sValue);
        }                

        aTriggers.PushString(szBuffer);
    }

    else if(Section == 2)
    {
        if(aTriggers.FindString(sKey) == -1)
                return SMCParse_Continue;

        aPhrases.PushString(sKey);
        aPhrases.PushString(sValue);
    }
    
    else
    {
        ColorLen =  (!strcmp(sKey, "Chat_PrototypeTeam"))   ? 0 : 
                    (!strcmp(sKey, "Chat_PrototypeAll"))    ? 1 : 
                    (!strcmp(sKey, "Changename_Prototype")) ? 2 : -1;
        
        if(ColorLen != -1)
            strcopy(msgPrototype[ColorLen], sizeof(msgPrototype[]), sValue);
    }

    return SMCParse_Continue;
}

public void OnParseEnded(SMCParser smc, bool halted, bool failed)
{
    clPoc_ParseEnded();
}

public Action ServerMsg_CB(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    static int Msg_type;
    Msg_type = (!umType) ? BfReadByte(msg) : PbReadInt(msg, "msg_dst");

    if(Msg_type != 3)
        return Plugin_Continue;

    static char szBuffer[MESSAGE_LENGTH];
    szBuffer = NULL_STRING;

    if(!umType) BfReadString(msg, SZ(szBuffer));
    else PbReadString(msg, "params", SZ(szBuffer), 0);

    if(!clProc_ServerMsg(SZ(szBuffer)) || !szBuffer[0])
        return Plugin_Handled;

    else if(szBuffer[0] == '#')
        return Plugin_Continue;

    Call_MessageBuilt(0, szBuffer);

    clProc_Replace(SZ(szBuffer), false);
    
    Format(SZ(szBuffer), "%c %s", 1, szBuffer);

    if(umType)
    {
        PbSetString(msg, "params", szBuffer, 0);
        return Plugin_Continue;
    }

    netMessage.Push(Msg_type);
    netMessage.PushString(szBuffer);
    netMessage.PushArray(players, playersNum);
    netMessage.Push(playersNum);
    RequestFrame(OnFrRequest);
    
    return Plugin_Handled;
}

public void OnFrRequest()
{
    char szMessage[MESSAGE_LENGTH];
    netMessage.GetString(1, SZ(szMessage));

    int[] players = new int[netMessage.Get(3)];
    netMessage.GetArray(2, players, netMessage.Get(3));

    BfWrite rewriteB = 
    UserMessageToBfWrite(
        StartMessage(
            "TextMsg", players, 
            netMessage.Get(3), 
            USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
        )
    );

    rewriteB.WriteByte(netMessage.Get(0));
    rewriteB.WriteString(szMessage);
    rewriteB.WriteString(NULL_STRING);
    EndMessage();

    netMessage.Clear();
}

public Action MsgText_CB(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    static char szName[NAME_LENGTH], szMessage[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    static int iIndex, MsgType;

    szName = "";
    szMessage = "";
    szBuffer = "";

    iIndex = (!umType) ? BfReadByte(msg) : PbReadInt(msg, "ent_idx");
    if(IsClientSourceTV(iIndex))
        return Plugin_Continue;
    
    if(game_mode)
        game_mode.ReplicateToClient(iIndex, mode_default_value);

    if(!umType)
    {        
        BfReadByte(msg);
        BfReadString(msg, SZ(szName));
    }
    else PbReadString(msg, "msg_name", SZ(szName));

    MsgType = (StrContains(szName, "Cstrike_Name_Change") != -1) ? 
                eMsg_CNAME : 
                view_as<int>(StrContains(szName, "_All") != -1); 

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

    clProc_Replace(SZ(szName), true);

    if(!clProc_SkipColors(iIndex))
        clProc_Replace(SZ(szMessage), true);

    GetMessageByPrototype(
        iIndex, MsgType, 
        GetClientTeam(iIndex), IsPlayerAlive(iIndex), 
        SZ(szName), SZ(szMessage), SZ(szBuffer)
    );
    
    if(!szMessage[0] || !szBuffer[0])
        return Plugin_Handled;
    
    Call_MessageBuilt(iIndex, szBuffer);

    clProc_Replace(SZ(szBuffer), false);

    if(game_mode)
        game_mode.ReplicateToClient(iIndex, "0");

    Call_IndexApproval(iIndex);

    if(umType)
    {
        PbSetInt(msg, "ent_idx", iIndex);
        PbSetString(msg, "msg_name", szBuffer);

        return Plugin_Continue;
    }

    netMessage.Push(iIndex);
    netMessage.PushString(szBuffer);
    netMessage.PushArray(players, playersNum);
    netMessage.Push(playersNum);

    return Plugin_Handled;
}

public void SayTextComp(UserMsg msgid, bool send)
{
    if(send && umType == UM_BitBuf && netMessage.Length)
    {
        char szMessage[MAX_LENGTH];
        netMessage.GetString(1, SZ(szMessage));

        int[] players = new int[netMessage.Get(3)];
        netMessage.GetArray(2, players, netMessage.Get(3));

        BfWrite bf = 
        UserMessageToBfWrite(
            StartMessage(
                "SayText2", players, 
                netMessage.Get(3), 
                USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
            )
        );

        bf.WriteByte(netMessage.Get(0));
        bf.WriteByte(1);
        bf.WriteString(szMessage);
        EndMessage();

        netMessage.Clear();
    }
}

void clProc_Replace(char[] szBuffer, int iSize, bool bToNullStr)
{
    static char szKey[STATUS_LENGTH], szColor[STATUS_LENGTH];
    szColor = "";
    szKey   = "";

    for(int i; i < aTriggers.Length; i++)
    {
        aTriggers.GetString(i, (bToNullStr || !(i%2)) ? szKey : szColor, STATUS_LENGTH);

        if(!bToNullStr && !(i%2))
            continue;

        ReplaceString(szBuffer, iSize, szKey, szColor, true);
    }
}

void GetMessageByPrototype
(
    int iIndex, int iType, int iTeam, bool IsAlive, char[] szName, 
    int NameSize, char[] szMessage, int MsgSize, char[] szBuffer, int iSize
)
{
    static char Other[MESSAGE_LENGTH];

    SetGlobalTransTarget(iIndex);

    //szBuffer[0] = 1;
    Other = "";

    clProc_MessageBroadType(iType);

    FormatEx(szBuffer, iSize, msgPrototype[iType]);

    clProc_RebuildString(iIndex, "{PROTOTYPE}", szBuffer, sizeof(msgPrototype[]));

    if(!szBuffer[0])
        return;

    Format(szBuffer, iSize, "%c %s", 1, szBuffer);
    
    if(StrContains(szBuffer, "{STATUS}") != -1)
    {
        if(iIndex)
            FormatEx(Other, STATUS_LENGTH, "%t", (IsAlive) ? "ClientStatus_Alive" : "ClientStatus_Died");
        
        clProc_RebuildString(iIndex, "{STATUS}", Other, STATUS_LENGTH);
        ReplaceString(szBuffer, iSize, "{STATUS}", Other, true);
    }

    if(StrContains(szBuffer, "{TEAM}") != -1 && iType != eMsg_CNAME)
    {
        if(iIndex)
            FormatEx(
                Other, TEAM_LENGTH, "%t", 
                (iTeam == 1 && iType) ? "TeamSPECAll" : 
                (iTeam == 1 && !iType) ? "TeamSPEC" :
                (iTeam == 2 && iType) ? "TeamTAll" :
                (iTeam == 2 && !iType) ? "TeamT" :
                (iTeam == 3 && iType) ? "TeamCTAll" :
                "TeamCT"
            );
        
        clProc_RebuildString(iIndex, "{TEAM}", Other, TEAM_LENGTH);
        ReplaceString(szBuffer, iSize, "{TEAM}", Other, true);
    }

    if(StrContains(szBuffer, "{PREFIX}") != -1)
    {
        Other = "";
        clProc_RebuildString(iIndex, "{PREFIX}", Other, PREFIX_LENGTH);        
        ReplaceString(szBuffer, iSize, "{PREFIX}", Other, true);
    }

    if(StrContains(szBuffer, "{NAME}") != -1)
    {
        clProc_RebuildString(iIndex, "{NAME}", szName, NameSize);
        ReplaceString(szBuffer, iSize, "{NAME}", szName, true);
    }
        
    if(StrContains(szBuffer, "{MSG}") != -1)
    {
        clProc_RebuildString(iIndex, "{MSG}", szMessage, MsgSize);
        TrimString(szMessage);

        ReplaceString(szBuffer, iSize, "{MSG}", szMessage, true);
    }
        
}

public int Native_ClearAllColors(Handle hPlugin, int iArgs)
{
    char szBuffer[MESSAGE_LENGTH];
    GetNativeString(1, SZ(szBuffer));

    clProc_Replace(SZ(szBuffer), true);

    SetNativeString(1, SZ(szBuffer));
}

public int Native_DropTriggers(Handle hPlugins, int iArgs)
{
    return view_as<int>(GetNativeCell(1) == 1 ? aTriggers.Clone() : aPhrases.Clone());
}

void clPoc_ParseEnded()
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("cc_config_parsed", ET_Ignore);
    
    Call_StartForward(gf);
    Call_Finish();
}

void clProc_RebuildString(int iClient, const char[] szBind, char[] szMessage, int iSize)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward(
            "cc_proc_RebuildString", 
            ET_Ignore, Param_Cell, 
            Param_CellByRef, Param_String, 
            Param_String, Param_Cell
        );
    
    int plevel;
    Call_StartForward(gf);
    Call_PushCell(iClient);
    Call_PushCellRef(plevel);
    Call_PushString(szBind);
    Call_PushStringEx(szMessage, iSize, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iSize);
    Call_Finish();
}

bool clProc_ServerMsg(char[] szMessage, int iSize)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("cc_proc_OnServerMsg", ET_Hook, Param_String, Param_Cell);
    
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
        gf = CreateGlobalForward("cc_proc_SkipColorsInMsg", ET_Hook, Param_Cell);
    
    bool skip = false;
    Call_StartForward(gf);
    Call_PushCell(iClient);
    Call_Finish(skip);

    return skip;
}

void clProc_MessageBroadType(const int iType)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("cc_proc_MsgBroadType", ET_Ignore, Param_Cell);
    
    Call_StartForward(gf);
    Call_PushCell(iType);
    Call_Finish();
}

void Call_IndexApproval(int &iIndex)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("cc_proc_IndexApproval", ET_Ignore, Param_CellByRef);
    
    int safe = iIndex;
    Call_StartForward(gf);
    Call_PushCellRef(iIndex);
    Call_Finish();

    if(iIndex < 1)
        iIndex = safe;
}

void Call_MessageBuilt(int iIndex, const char[] BuiltMessage)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("cc_proc_OnMessageBuilt", ET_Ignore, Param_Cell, Param_String);
    
    Call_StartForward(gf);
    Call_PushCell(iIndex);
    Call_PushString(BuiltMessage)
    Call_Finish();
}