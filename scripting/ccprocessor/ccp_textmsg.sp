#define MAX_PARAMS 5

public Action UserMessage_TextMsg(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if(((!umType) ? BfReadByte(msg) : PbReadInt(msg, "msg_dst")) != 3)
        return Plugin_Continue;

    static char szName[NAME_LENGTH], szMessage[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    szName = NULL_STRING;
    szBuffer = NULL_STRING;
    szMessage = NULL_STRING;

    static Action defMessage;
    defMessage = Plugin_Continue;

    if(!umType) BfReadString(msg, SZ(szMessage));
    else PbReadString(msg, "params", SZ(szMessage), 0);

    //LogMessage(szMessage);

    if(szMessage[0] == '#')
    {
        defMessage = Call_OnDefMessage(szMessage, TranslationPhraseExists(szMessage), IsTranslatedForLanguage(szMessage, GetServerLanguage()));

        if(defMessage == Plugin_Changed)
            PrepareDefMessage(SZ(szMessage));
        
        else return defMessage;
    }

    szName = "CONSOLE";
        
    GetMessageByPrototype(
        eIdx, eMsg_SERVER, eIdx+1, false, SZ(szName), SZ(szMessage), SZ(szBuffer)
    );

    if(!szMessage[0] || !szBuffer[0])
        return Plugin_Handled;

    Call_MessageBuilt(eIdx, szBuffer);

    ReplaceColors(SZ(szBuffer), false);

    if(umType)
    {
        PbSetString(msg, "params", szBuffer, 0);
        return Plugin_Continue;
    }

    netMessage.Push(3);
    netMessage.PushString(szBuffer);
    netMessage.PushArray(players, playersNum);
    netMessage.Push(playersNum);

    if(defMessage == Plugin_Changed)
        ReadBfParams(view_as<BfRead>(msg));

    RequestFrame(TextMsg_Completed, msg_id);
    
    return Plugin_Handled;
}

public void TextMsg_Completed(any data)
{
    char szMessage[MESSAGE_LENGTH];
    netMessage.GetString(eMsg, SZ(szMessage));

    int[] players = new int[netMessage.Get(eCount)];
    netMessage.GetArray(eArray, players, netMessage.Get(eCount));

    char szParams[MAX_PARAMS][MESSAGE_LENGTH];

    if(netMessage.Length > eAny)
    {
        for(int i = eAny, a; i < netMessage.Length; i++)
        {
            if(a >= MAX_PARAMS)
                break;

            netMessage.GetString(i, szParams[a++], sizeof(szParams[]));
        }
    }
    
    BfWrite message = 
    view_as<BfWrite>(
        StartMessageEx(
            data, players, 
            netMessage.Get(eCount), 
            USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
        )
    );

    if(message && message != INVALID_HANDLE)
    {
        message.WriteByte(netMessage.Get(eIdx));
        message.WriteString(szMessage);
        for(int i; i < MAX_PARAMS; i++)
            message.WriteString(szParams[i]);

        EndMessage();
    }

    netMessage.Clear();
}

void ReadBfParams(BfRead message)
{
    char szParam[MESSAGE_LENGTH];

    while(message.BytesLeft != 0)
    {
        if(message.BytesLeft == 1)
            break;
            
        message.ReadString(szParam, sizeof(szParam));
        netMessage.PushString(szParam);
    }
}

void PrepareDefMessage(char[] szMessage, int size)
{
    char szNum[8];

    Format(szMessage, size, "%T", szMessage, LANG_SERVER);

    for(int i = 1; i <= MAX_PARAMS; i++)
    {
        FormatEx(szNum, sizeof(szNum), "{%i}", i);
        ReplaceString(szMessage, size, szNum, (i == 1) ? "%s1" : (i == 2) ? "%s2" : (i == 3) ? "%s3" : (i==4) ? "%s4" : "%s5");
    }
}