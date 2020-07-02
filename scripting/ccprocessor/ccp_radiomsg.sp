public Action UserMessage_RadioText(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    /*
        optional int32 msg_dst = 1;
        optional int32 client = 2;
        optional string msg_name = 3;
        repeated string params = 4;
    */

    if(((!umType) ? BfReadByte(msg) : PbReadInt(msg, "msg_dst")) != 3)
        return Plugin_Continue;

    static char szName[NAME_LENGTH], szKey[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    szKey = NULL_STRING;
    szName = NULL_STRING;
    szBuffer = NULL_STRING;

    static const char szMessage[] = "%s3";
    static const int iType = eMsg_RADIO; 

    static int iIndex, iBackupIndex;
    iIndex = iBackupIndex = 0;

    static Protobuf message;
    message = null;

    iIndex = 
        (!umType) ? 
            ReadRadioAsBf(view_as<BfRead>(msg), SZ(szName), SZ(szKey)) :
            ReadRadioAsProto(view_as<Protobuf>(msg), SZ(szName), SZ(szKey));

    if(Call_RestrictRadioKey(iIndex, szKey))
        return Plugin_Handled;

    ReplaceColors(SZ(szName), true);

    GetMessageByPrototype(
        iIndex, iType, GetClientTeam(iIndex), IsPlayerAlive(iIndex), SZ(szName), SZ(szKey), SZ(szBuffer)
    );

    if(!szBuffer[0])
        return Plugin_Handled;
    
    ReplaceString(szBuffer, sizeof(szBuffer), "{MSG}", szMessage);

    Call_MessageBuilt(iIndex, szBuffer);

    ReplaceColors(SZ(szBuffer), false);

    iBackupIndex = iIndex;
    Call_IndexApproval(iIndex);

    if(game_mode)
        game_mode.ReplicateToClient(iBackupIndex, "0");
    
    if(umType)
    {
        message = view_as<Protobuf>(msg);
        message.SetInt("client", iIndex);
        message.SetString("msg_name", szBuffer);

        RequestFrame(BackMode, iBackupIndex);
        return Plugin_Continue;
    }

    netMessage.Push(iIndex);
    netMessage.PushString(szBuffer);
    netMessage.PushArray(players, playersNum);
    netMessage.Push(playersNum);
    netMessage.Push(iBackupIndex);
    netMessage.PushString(szKey);

    return Plugin_Handled;
}

public void RadioText_Completed(UserMsg msgid, bool send)
{
    if(!umType && netMessage.Length)
    {
        if(send)
        {
            char szMessage[MAX_LENGTH];
            netMessage.GetString(eMsg, SZ(szMessage));

            int[] players = new int[netMessage.Get(eCount)];
            netMessage.GetArray(eArray, players, netMessage.Get(eCount));

            char szKey[MESSAGE_LENGTH];
            netMessage.GetString(eAny+1, szKey, sizeof(szKey));

            BfWrite message = 
            view_as<BfWrite>(
                StartMessageEx(
                    msgid, players, 
                    netMessage.Get(eCount), 
                    USERMSG_RELIABLE|USERMSG_BLOCKHOOKS
                )
            );

            if(message && message != INVALID_HANDLE)
            {
                message.WriteByte(3);
                message.WriteByte(netMessage.Get(eIdx));
                message.WriteString(szMessage);
                message.WriteString("1");
                message.WriteString("1");
                message.WriteString(szKey);
                EndMessage();
            }
        }

        BackMode(netMessage.Get(eAny));
    }

    netMessage.Clear();
}

int ReadRadioAsBf(BfRead message, char[] szName, int nsize, char[] szRKey, int ksize)
{
    int iIndex = message.ReadByte();

    message.ReadString(szName, nsize);
    message.ReadString(szName, nsize);

    message.ReadString(szRKey, ksize);
    message.ReadString(szRKey, ksize);

    strcopy(szName, nsize, szName[FindCharInString(szName, ']')+1]);

    return iIndex;
}

int ReadRadioAsProto(Protobuf message, char[] szName, int nsize, char[] szRKey, int ksize)
{
    message.ReadString("params", szName, nsize, 0);
    message.ReadString("params", szRKey, ksize, 2);

    strcopy(szName, nsize, szName[FindCharInString(szName, ']')+1]);

    return message.ReadInt("client");
}