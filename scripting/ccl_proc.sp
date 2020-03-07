
#pragma newdecls required

#define STANDART_INFO

#define PlugName "CCLProcessor"
#define PlugDesc "Extended color chat processor"
#define PlugVer "1.0.3 Beta"

#include std

#define SETTINGS_PATH "configs/c_var/%s.ini"

EngineVersion eEngine;

/* CSGO: Proto - SayText2, CSS OB: BF - SayText2 */
UserMessageType umType;

/* Key:Color*/
ArrayList aTriggers;

char szGameFolder[PMP];
char msgPrototype[2][64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{    
    eEngine = GetEngineVersion();

    if(eEngine != Engine_CSGO && eEngine != Engine_CSS)
        return APLRes_Failure;

    /* TODO: Add support for bf based engine */
    umType = GetUserMessageType();

    HookUserMessage(GetUserMessageId("TextMsg"), ServerMsg_CB, true);
    HookUserMessage(GetUserMessageId("SayText2"), MsgText_CB, true);

    RegPluginLibrary("ccl_proc");

    return APLRes_Success;
}

public void OnPluginStart()
{
    GetGameFolderName(SZ(szGameFolder));
    LoadTranslations("cclproc.phrases");

    aTriggers = new ArrayList(64, PMP);
}

public void OnMapStart()
{
    char szPath[PMP];
    FormatEx(SZ(szPath), SETTINGS_PATH, szGameFolder);

    BUILD(szPath, szPath);

    ReadConfig(szPath);
}

void ReadConfig(const char[] szPath)
{
    aTriggers.Clear();

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;

    if(!FileExists(szPath))
        SetFailState("Where is my config??");
    
    int iLine;

    if(smParser.ParseFile(szPath, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %d", szPath, iLine);
}

SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;
    
    static char szBuffer[16];

    if(!strcmp(sKey, "Chat_PrototypeTeam"))
        strcopy(msgPrototype[0], sizeof(msgPrototype[]), sValue);
    
    else if(!strcmp(sKey, "Chat_PrototypeAll"))
        strcopy(msgPrototype[1], sizeof(msgPrototype[]), sValue);


    if(strlen(sValue) > 7)
        return SMCParse_Continue;

    aTriggers.PushString(sKey);

    
    if(strlen(sValue) > 3)
        FormatEx(SZ(szBuffer), "\x07%s", sValue);
    else
        FormatEx(SZ(szBuffer), "%c", StringToInt(sValue));

    aTriggers.PushString(szBuffer);

    return SMCParse_Continue;
}

public Action ServerMsg_CB(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    static int Msg_type;

    /* 0 - ? | 1 - Console | 2 - Console | 3 - Chat | 4 - Hint | 5 - ?*/
    Msg_type = (!umType) ? BfReadByte(msg) : PbReadInt(msg, "msg_dst");
    if(Msg_type != 3)
        return Plugin_Continue;

    static char szBuffer[PMP];

    if(!umType) BfReadString(msg, SZ(szBuffer));
    else PbReadString(msg, "params", SZ(szBuffer), 0);

    //LogMessage("Read: %s", szBuffer);

    clProc_ServerMsg(SZ(szBuffer));
    clProc_Replace(SZ(szBuffer));
    
    Format(SZ(szBuffer), "%c %s", 1, szBuffer);
    //LogMessage("Changed: %s", szBuffer);

    if(umType)
    {
        PbSetString(msg, "params", szBuffer, 0);
        return Plugin_Continue;
    }

    DataPack dp = new DataPack();
    dp.WriteCell(0); // ClientMsg
    dp.WriteCell(Msg_type); // Type
    dp.WriteString(szBuffer); // Buffer

    ArrayList arr = new ArrayList(6, 0);
    for(int i; i < playersNum; i++)
        arr.Push(players[i]);
    
    dp.WriteCell(arr); // Players

    RequestFrame(BfRewriteMsg, dp);
    
    return Plugin_Handled;
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

    static char szName[MNL];
    static char szMessage[PMP];
    static int iIndex;

    char szBuffer[512];
    DataPack dp;
    bool ToAll;

    iIndex = (!umType) ? BfReadByte(msg) : PbReadInt(msg, "ent_idx");

    if(!umType)
    {
        dp = new DataPack();
        dp.WriteCell(1); // ClientMsg
        dp.WriteCell(iIndex); //Index
        
        BfReadByte(msg);
        BfReadString(msg, SZ(szName));
    }

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

    GetMessageByPrototype(iIndex, GetClientTeam(iIndex), (iIndex) ? IsPlayerAlive(iIndex) : false, ToAll, SZ(szName), SZ(szMessage), SZ(szBuffer));
    clProc_Replace(SZ(szBuffer));

    if(umType)
    {
        PbSetInt(msg, "ent_idx", iIndex);
        PbSetString(msg, "msg_name", szBuffer);

        return Plugin_Continue;
    }

    ArrayList arr = new ArrayList(6, 0);

    for(int i; i < playersNum; i++)
        arr.Push(players[i]);
    
    dp.WriteString(szBuffer); // Buffer
    dp.WriteCell(arr); // Players

    RequestFrame(BfRewriteMsg, dp);

    return Plugin_Handled;
}

public void BfRewriteMsg(any data)
{
    static char szBuffer[512];

    DataPack dp = data;
    dp.Reset();

    bool ClientMsg = view_as<bool>(dp.ReadCell());
    int iCell = dp.ReadCell();
    dp.ReadString(SZ(szBuffer));

    ArrayList arr = dp.ReadCell();
    int iCount = arr.Length;

    int[] players = new int[iCount];

    for(int i; i < iCount; i++)
        players[i] = arr.Get(i);
    
    delete arr;
    delete dp;

    static BfWrite rewriteB;

    rewriteB = UserMessageToBfWrite(StartMessage((ClientMsg) ? "SayText2" : "TextMsg", players, iCount, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
    
    rewriteB.WriteByte(iCell);
    if(ClientMsg)
        rewriteB.WriteByte(1);
    rewriteB.WriteString(szBuffer);

    EndMessage();
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

void clProc_ServerMsg(char[] szMessage, int iSize)
{
    static Handle gf;
    if(!gf)
        gf = CreateGlobalForward("ccl_proc_OnServerMsg", ET_Ignore, Param_String, Param_Cell);
    
    Call_StartForward(gf);
    Call_PushStringEx(szMessage, iSize, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(iSize);
    Call_Finish();
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
        ReplaceString(szBuffer, iSize, "{MSG}", szMesage, true);
    }
        
}
