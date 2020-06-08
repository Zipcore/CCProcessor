#pragma newdecls required

#define SETTINGS_PATH "configs/c_var/%s.ini"
#define SZ(%0) %0, sizeof(%0)

#include ccprocessor

UserMessageType umType;

ArrayList 
    aPalette,
    netMessage;

char 
    szConfigPath[MESSAGE_LENGTH],
    msgPrototype[eMsg_MAX][MESSAGE_LENGTH];

ConVar game_mode;

char mode_default_value[8];

public Plugin myinfo = 
{
    name        = "CCProcessor",
    author      = "nullent?",
    description = "Color chat processor",
    version     = "2.1.2",
    url         = "discord.gg/ChTyPUG"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{    
    umType = GetUserMessageType();

    HookUserMessage(GetUserMessageId("TextMsg"), TextMessage_CallBack, true);
    HookUserMessage(GetUserMessageId("SayText2"), SayText2_CallBack, true, SayTextComp);

    CreateNative("cc_drop_palette", Native_DropPalette);
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

    aPalette = new ArrayList(PREFIX_LENGTH, 0);
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

SMCParser smParser;

public void OnMapStart()
{
    if(!FileExists(szConfigPath))
        SetFailState("Where is my config: %s ???", szConfigPath);

    aPalette.Clear();
    
    smParser = new SMCParser();
    smParser.OnKeyValue = OnKeyValue;
    smParser.OnEnterSection = OnEnterSection;
    smParser.OnEnd = OnCompReading;
    smParser.OnLeaveSection = OnLeave;

    int iLine;
    if(smParser.ParseFile(szConfigPath, iLine) != SMCError_Okay)
        LogError("An error was detected on line '%i' while reading", iLine);
}

public void OnConfigsExecuted()
{
    if(game_mode)
        game_mode.Flags |= FCVAR_REPLICATED;
}

int Section;

SMCResult OnEnterSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    // main ++ > 1 Palette ++ > 2 Key
    if(Section > 1)
        aPalette.PushString(name);

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
    }

    else
    {
        iBuffer =   (!strcmp(sKey, "Chat_PrototypeTeam"))   ? eMsg_TEAM : 
                    (!strcmp(sKey, "Chat_PrototypeAll"))    ? eMsg_ALL : 
                    (!strcmp(sKey, "Changename_Prototype")) ? eMsg_CNAME : 
                    (!strcmp(sKey, "Chat_ServerTemplate"))  ? eMsg_SERVER : -1;
        
        if(iBuffer != -1)
            strcopy(msgPrototype[iBuffer], sizeof(msgPrototype[]), sValue);
    }

    return SMCParse_Continue;
}

public void OnCompReading(SMCParser smc, bool halted, bool failed)
{
    delete smParser; 

    if(!halted && !failed)
        Call_OnCompReading();

    else SetFailState("There was a problem reading the configuration file");
}

public Action TextMessage_CallBack(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if(((!umType) ? BfReadByte(msg) : PbReadInt(msg, "msg_dst")) != 3)
        return Plugin_Continue;

    static char szName[NAME_LENGTH], szMessage[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    szName = NULL_STRING;
    szMessage = NULL_STRING;
    szBuffer = NULL_STRING;

    if(!umType) BfReadString(msg, SZ(szMessage));
    else PbReadString(msg, "params", SZ(szMessage), 0);

    if(szMessage[0] == '#')
        return Call_OnDefMessage(szMessage) ? Plugin_Continue : Plugin_Handled;

    GetMessageByPrototype(
        0, eMsg_SERVER, 1, false, SZ(szName), SZ(szMessage), SZ(szBuffer)
    );

    if(!szMessage[0] || !szBuffer[0])
        return Plugin_Handled;

    Call_MessageBuilt(0, szBuffer);

    ReplaceColors(SZ(szBuffer), false);
    
    //Format(SZ(szBuffer), "%c %s", 1, szBuffer);

    if(umType)
    {
        PbSetString(msg, "params", szBuffer, 0);
        return Plugin_Continue;
    }

    netMessage.Push(3);
    netMessage.PushString(szBuffer);
    netMessage.PushArray(players, playersNum);
    netMessage.Push(playersNum);
    RequestFrame(SendSrvMsgSafly, msg_id);
    
    return Plugin_Handled;
}

public void SendSrvMsgSafly(any data)
{
    char szMessage[MESSAGE_LENGTH];
    netMessage.GetString(1, SZ(szMessage));

    int[] players = new int[netMessage.Get(3)];
    netMessage.GetArray(2, players, netMessage.Get(3));

    BfWrite message = 
    view_as<BfWrite>(
        StartMessageEx(
            data, players, 
            netMessage.Get(3), 
            USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
        )
    );

    if(message && message != INVALID_HANDLE)
    {
        message.WriteByte(netMessage.Get(0));
        message.WriteString(szMessage);
        message.WriteString(NULL_STRING);
        message.WriteString(NULL_STRING);

        EndMessage();
    }

    netMessage.Clear();
}

public Action SayText2_CallBack(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    Protobuf message;

    static int iIndex, MsgType, iBackupIndex;

    static char szName[NAME_LENGTH], szMessage[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    
    if(!umType) ReadBfMessage(msg, iIndex, MsgType, SZ(szName), SZ(szMessage));
    
    else ReadProtoMessage(msg, iIndex, MsgType, SZ(szName), SZ(szMessage));

    if(IsClientSourceTV(iIndex))
        return Plugin_Continue;
    
    // If a player has added colors into his nickname
    ReplaceColors(SZ(szName), true);

    // If a player has added colors into his msg
    if(!Call_IsSkipColors(iIndex))
        ReplaceColors(SZ(szMessage), true);
    
    GetMessageByPrototype(
        iIndex, MsgType, GetClientTeam(iIndex), IsPlayerAlive(iIndex), SZ(szName), SZ(szMessage), SZ(szBuffer)
    );

    if(!szMessage[0] || !szBuffer[0])
        return Plugin_Handled;
    
    Call_MessageBuilt(iIndex, szBuffer);
    ReplaceColors(SZ(szBuffer), false);

    iBackupIndex = iIndex;
    Call_IndexApproval(iIndex);

    if(game_mode)
        game_mode.ReplicateToClient(iBackupIndex, "0");
    
    if(umType)
    {
        message = view_as<Protobuf>(msg);
        message.SetInt("ent_idx", iIndex);
        message.SetString("msg_name", szBuffer);

        RequestFrame(BackMode, iBackupIndex);
        return Plugin_Continue;
    }

    netMessage.Push(iIndex);
    netMessage.PushString(szBuffer);
    netMessage.PushArray(players, playersNum);
    netMessage.Push(playersNum);
    netMessage.Push(iBackupIndex);

    return Plugin_Handled;
}

public void BackMode(any data)
{
    if(game_mode)
        game_mode.ReplicateToClient(data, mode_default_value);
}

public void SayTextComp(UserMsg msgid, bool send)
{
    if(!umType && netMessage.Length)
    {
        if(send)
        {
            char szMessage[MAX_LENGTH];
            netMessage.GetString(1, SZ(szMessage));

            int[] players = new int[netMessage.Get(3)];
            netMessage.GetArray(2, players, netMessage.Get(3));

            BfWrite message = 
            view_as<BfWrite>(
                StartMessageEx(
                    msgid, players, 
                    netMessage.Get(3), 
                    USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
                )
            );

            if(message && message != INVALID_HANDLE)
            {
                message.WriteByte(netMessage.Get(0));
                message.WriteByte(1);
                message.WriteString(szMessage);
                EndMessage();
            }
        }

        BackMode(netMessage.Get(4));
        netMessage.Clear();
    }
}

void ReadProtoMessage(Handle msg, int &iSender, int &iMsgType, char[] szSenderName, int sn_size, char[] szSenderMsg, int sm_size)
{
    Protobuf message = view_as<Protobuf>(msg);

    iSender = message.ReadInt("ent_idx");
    
    message.ReadString("msg_name", szSenderName, sn_size);
    iMsgType = GetMessageType(szSenderName);

    message.ReadString("params", szSenderName, sn_size, 0);
    message.ReadString("params", szSenderMsg, sm_size, 1);
}

void ReadBfMessage(Handle msg, int &iSender, int &iMsgType, char[] szSenderName, int sn_size, char[] szSenderMsg, int sm_size)
{
    BfRead message = view_as<BfRead>(msg);

    // Sender
    iSender = message.ReadByte();
    
    // Is chat
    message.ReadByte();
    
    // msg_name
    message.ReadString(szSenderName, sn_size);
    iMsgType = GetMessageType(szSenderName);

    // param 0
    message.ReadString(szSenderName, sn_size);

    // param 1
    message.ReadString(szSenderMsg, sm_size);    
}

int GetMessageType(char[] szMsgPhrase)
{
    return (StrContains(szMsgPhrase, "Cstrike_Name_Change") != -1) ? eMsg_CNAME : view_as<int>(StrContains(szMsgPhrase, "_All") != -1); 
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
    Other = "";

    SetGlobalTransTarget(iIndex);

    Call_MessageBroadType(iType);

    FormatEx(szBuffer, iSize, msgPrototype[iType]);

    Call_RebuildString(iIndex, "{PROTOTYPE}", szBuffer, iSize);

    if(!szBuffer[0])
        return;

    Format(szBuffer, iSize, "%c %s", 1, szBuffer);
    
    if(StrContains(szBuffer, "{STATUS}") != -1)
    {
        FormatEx(SZ(Other), "%t", (IsAlive) ? "ClientStatus_Alive" : "ClientStatus_Died");

        Call_RebuildString(iIndex, "{STATUS}", SZ(Other));

        BreakPoint(Other, STATUS_LENGTH);
        ReplaceString(szBuffer, iSize, "{STATUS}", Other, true);
    }

    if(StrContains(szBuffer, "{TEAM}") != -1 && iType != eMsg_CNAME)
    {
        FormatEx(
            Other, TEAM_LENGTH, "%t", 
            (iTeam == 1 && iType) ? "TeamSPECAll" : 
            (iTeam == 1 && !iType) ? "TeamSPEC" :
            (iTeam == 2 && iType) ? "TeamTAll" :
            (iTeam == 2 && !iType) ? "TeamT" :
            (iTeam == 3 && iType) ? "TeamCTAll" :
            "TeamCT"
        );
        
        Call_RebuildString(iIndex, "{TEAM}", SZ(Other));

        BreakPoint(Other, TEAM_LENGTH);
        ReplaceString(szBuffer, iSize, "{TEAM}", Other, true);
    }

    // This isn't the best solution, but so far everything is in order.... i think.
    if(StrContains(szBuffer, "{PREFIXCO}") != -1)
    {
        Other = "";
        Call_RebuildString(iIndex, "{PREFIXCO}", SZ(Other));

        BreakPoint(Other, STATUS_LENGTH);        
        ReplaceString(szBuffer, iSize, "{PREFIXCO}", Other, true);
    }

    if(StrContains(szBuffer, "{PREFIX}") != -1)
    {
        Other = "";
        Call_RebuildString(iIndex, "{PREFIX}", SZ(Other));

        BreakPoint(Other, PREFIX_LENGTH);        
        ReplaceString(szBuffer, iSize, "{PREFIX}", Other, true);
    }

    if(StrContains(szBuffer, "{NAMECO}") != -1)
    {
        FormatEx(SZ(Other), "%c", 3);
        Call_RebuildString(iIndex, "{NAMECO}", SZ(Other));

        BreakPoint(Other, STATUS_LENGTH);        
        ReplaceString(szBuffer, iSize, "{NAMECO}", Other, true);
    }

    if(StrContains(szBuffer, "{NAME}") != -1)
    {
        if(!iIndex && iType == eMsg_SERVER)
            FormatEx(szName, NameSize, "CONSOLE");
            
        Call_RebuildString(iIndex, "{NAME}", szName, NameSize);
        ReplaceString(szBuffer, iSize, "{NAME}", szName, true);
    }

    if(StrContains(szBuffer, "{MSGCO}") != -1)
    {
        FormatEx(SZ(Other), "%c", 1);
        Call_RebuildString(iIndex, "{MSGCO}", SZ(Other));

        BreakPoint(Other, STATUS_LENGTH);        
        ReplaceString(szBuffer, iSize, "{MSGCO}", Other, true);
    }

    if(StrContains(szBuffer, "{MSG}") != -1)
    {
        Call_RebuildString(iIndex, "{MSG}", szMessage, MsgSize);
        TrimString(szMessage);

        ReplaceString(szBuffer, iSize, "{MSG}", szMessage, true);
    }
}

void BreakPoint(char[] szValue, int MaxLength)
{
    if(strlen(szValue) >= MaxLength)
        szValue[MaxLength] = 0;
}

public int Native_ClearAllColors(Handle hPlugin, int iArgs)
{
    char szBuffer[MESSAGE_LENGTH];
    GetNativeString(1, SZ(szBuffer));

    ReplaceColors(SZ(szBuffer), true);

    SetNativeString(1, SZ(szBuffer));
}

public int Native_DropPalette(Handle hPlugins, int iArgs)
{
    return view_as<int>(aPalette.Clone());
}

void Call_OnCompReading()
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward("cc_config_parsed", ET_Ignore);
    
    Call_StartForward(gf);
    Call_Finish();
}

void Call_RebuildString(int iClient, const char[] szBind, char[] szMessage, int iSize)
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward(
            "cc_proc_RebuildString", ET_Ignore, Param_Cell, Param_CellByRef, Param_String, Param_String, Param_Cell
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

bool Call_OnDefMessage(const char[] szMessage)
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward("cc_proc_OnDefMsg", ET_Hook, Param_String);
    
    bool Send = true;
    Call_StartForward(gf);
    Call_PushString(szMessage);
    Call_Finish(Send);

    return Send;
}

bool Call_IsSkipColors(int iClient)
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward("cc_proc_SkipColorsInMsg", ET_Hook, Param_Cell);
    
    bool skip = false;
    Call_StartForward(gf);
    Call_PushCell(iClient);
    Call_Finish(skip);

    return skip;
}

void Call_MessageBroadType(const int iType)
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward("cc_proc_MsgBroadType", ET_Ignore, Param_Cell);
    
    Call_StartForward(gf);
    Call_PushCell(iType);
    Call_Finish();
}

void Call_IndexApproval(int &iIndex)
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward("cc_proc_IndexApproval", ET_Ignore, Param_CellByRef);
    
    int safe = iIndex;
    Call_StartForward(gf);
    Call_PushCellRef(iIndex);
    Call_Finish();

    if(iIndex < 1)
        iIndex = safe;
}

void Call_MessageBuilt(int iIndex, const char[] BuiltMessage)
{
    static GlobalForward gf;
    if(!gf)
        gf = new GlobalForward("cc_proc_OnMessageBuilt", ET_Ignore, Param_Cell, Param_String);
    
    Call_StartForward(gf);
    Call_PushCell(iIndex);
    Call_PushString(BuiltMessage)
    Call_Finish();
}