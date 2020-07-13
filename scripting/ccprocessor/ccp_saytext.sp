
/*
    This is a personal update for `level-ranks` users, which uses `SayText` for messages from the plugin.
    The hook allows you to build a message according to the internal patterns of the core.
*/

public Action UserMessage_SayText(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if(((!umType) ? BfReadByte(msg) : PbReadInt(msg, "ent_idx")) != 0)
        return Plugin_Continue;

    static char szName[NAME_LENGTH], szMessage[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    szName = NULL_STRING;
    szBuffer = NULL_STRING;
    szMessage = NULL_STRING;

    if(!umType) BfReadString(msg, SZ(szMessage));
    else PbReadString(msg, "text", SZ(szMessage));

    if(!((!umType) ? view_as<bool>(BfReadByte(msg)) : PbReadBool(msg, "chat")))
        return Plugin_Continue;

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
        PbSetString(msg, "text", szBuffer);
        return Plugin_Continue;
    }

    {
        ArrayList arr = new ArrayList(sizeof(szBuffer), 0);
        arr.Push(msg_id);
        arr.PushString(szBuffer);
        arr.PushArray(players, playersNum);
        arr.Push(playersNum);

        RequestFrame(SayText_Completed, arr);
    }
    
    return Plugin_Handled;
}

public void SayText_Completed(any data)
{
    ArrayList arr = view_as<ArrayList>(data);

    char szMessage[MESSAGE_LENGTH];
    netMessage.GetString(eMsg, SZ(szMessage));

    int[] players = new int[netMessage.Get(eCount)];
    netMessage.GetArray(eArray, players, netMessage.Get(eCount));
    
    BfWrite message = 
    view_as<BfWrite>(
        StartMessageEx(
            netMessage.Get(eIdx), players, 
            netMessage.Get(eCount), 
            USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
        )
    );

    if(message && message != INVALID_HANDLE)
    {
        message.WriteByte(0);
        message.WriteString(szMessage);
        message.WriteByte(true);

        EndMessage();
    }

    delete arr;
}