public Action UserMessage_SayText2(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    static Protobuf message;
    message = null;

    static int iIndex, MsgType, iBackupIndex;
    iIndex = iBackupIndex = MsgType = 0;

    static char szName[NAME_LENGTH], szMessage[MESSAGE_LENGTH], szBuffer[MAX_LENGTH];
    szName = NULL_STRING;
    szBuffer = NULL_STRING;
    szMessage = NULL_STRING;

    iIndex = 
        (!umType) ? 
            ReadBfMessage(view_as<BfRead>(msg), MsgType, SZ(szName), SZ(szMessage)) :
            ReadProtoMessage(view_as<Protobuf>(msg), MsgType, SZ(szName), SZ(szMessage));
    
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

public void SayText2_Completed(UserMsg msgid, bool send)
{
    if(!umType && netMessage.Length)
    {
        if(send)
        {
            char szMessage[MAX_LENGTH];
            netMessage.GetString(eMsg, SZ(szMessage));

            int[] players = new int[netMessage.Get(eCount)];
            netMessage.GetArray(eArray, players, netMessage.Get(eCount));

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
                message.WriteByte(netMessage.Get(eIdx));
                message.WriteByte(true);
                message.WriteString(szMessage);
                EndMessage();
            }
        }

        BackMode(netMessage.Get(eAny));
        netMessage.Clear();
    }
}

int ReadProtoMessage(Protobuf message, int &iMsgType, char[] szSenderName, int sn_size, char[] szSenderMsg, int sm_size)
{   
    message.ReadString("msg_name", szSenderName, sn_size);
    iMsgType = GetSayTextType(szSenderName);

    message.ReadString("params", szSenderName, sn_size, 0);
    message.ReadString("params", szSenderMsg, sm_size, 1);

    return message.ReadInt("ent_idx");
}

int ReadBfMessage(BfRead message, int &iMsgType, char[] szSenderName, int sn_size, char[] szSenderMsg, int sm_size)
{
    // Sender
    int iSender = message.ReadByte();
    
    // Is chat
    message.ReadByte();
    
    // msg_name
    message.ReadString(szSenderName, sn_size);
    iMsgType = GetSayTextType(szSenderName);

    // param 0
    message.ReadString(szSenderName, sn_size);

    // param 1
    message.ReadString(szSenderMsg, sm_size);

    return iSender;   
}

int GetSayTextType(char[] szMsgPhrase)
{
    return (StrContains(szMsgPhrase, "Cstrike_Name_Change") != -1) ? eMsg_CNAME : view_as<int>(StrContains(szMsgPhrase, "_All") != -1); 
}