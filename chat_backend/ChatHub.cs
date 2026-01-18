using Microsoft.AspNetCore.SignalR;

public class ChatHub : Hub
{

    private readonly FcmService _fcm;

    public ChatHub(FcmService fcm)
    {
        _fcm = fcm;
    }

    // Client calls: RegisterUser(eventId, userId)
    public async Task RegisterUser(int eventId, int userId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"event:{eventId}");
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");

        Context.Items["eventId"] = eventId;
        Context.Items["userId"] = userId;

        lock (ChatStore.LockObj)
        {
            ChatStore.OnlineConnections.TryGetValue(userId, out var c);
            ChatStore.OnlineConnections[userId] = c + 1;
        }
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        if (Context.Items.TryGetValue("userId", out var v) && v is int userId)
        {
            lock (ChatStore.LockObj)
            {
                if (ChatStore.OnlineConnections.TryGetValue(userId, out var c))
                {
                    c--;
                    if (c <= 0) ChatStore.OnlineConnections.Remove(userId);
                    else ChatStore.OnlineConnections[userId] = c;
                }
            }
        }

        return base.OnDisconnectedAsync(exception);
    }

    // Client calls: SendMessage(eventId, receiverId, messageText)
    public async Task SendMessage(int eventId, int receiverId, string messageText)
    {
        var senderId = GetUserIdOrThrow();

        ChatMessage msg;
        lock (ChatStore.LockObj)
        {
            var id = ChatStore.NextId++;
            msg = new ChatMessage(
                Id: id,
                EventId: eventId,
                SenderId: senderId,
                ReceiverId: receiverId,
                MessageText: messageText,
                Timestamp: DateTime.UtcNow.ToString("o"),
                IsRead: false
            );
            ChatStore.Messages.Add(msg);
        }

        // Server event: ReceiveMessage
        // args: [eventId, senderId, receiverId, messageText, messageId]
        await Clients.Group($"user:{receiverId}")
            .SendAsync("ReceiveMessage", eventId, senderId, receiverId, msg.MessageText, msg.Id);

        // Echo to sender
        await Clients.Group($"user:{senderId}")
            .SendAsync("ReceiveMessage", eventId, senderId, receiverId, msg.MessageText, msg.Id);

        // ✅ Push Notification للـ receiver
string? token = null;
 bool receiverOnline;
lock (ChatStore.LockObj)
{
    ChatStore.UserTokens.TryGetValue(receiverId, out token);
    receiverOnline = ChatStore.OnlineConnections.ContainsKey(receiverId);
}

 if (!receiverOnline && !string.IsNullOrWhiteSpace(token))
{
    try
    {
        await _fcm.SendToTokenAsync(
            token!,
            title: $"New message from {senderId}",
            body: messageText,
            data: new Dictionary<string, string>
            {
                ["eventId"] = eventId.ToString(),
                ["senderId"] = senderId.ToString(),
                ["receiverId"] = receiverId.ToString()
            }
        );
    }
    catch (Exception ex)
    {
        // مهم: فشل الـ push ما يوقفش SendMessage
        Console.WriteLine("FCM error: " + ex.Message);
    }
}


        // Server event: UnReadMessageCountForUser
        int count;
        lock (ChatStore.LockObj)
        {
            count = ChatStore.Messages.Count(m =>
                m.EventId == eventId &&
                m.ReceiverId == receiverId &&
                m.SenderId == senderId &&
                !m.IsRead
            );
        }

        // args: [eventId, senderId, receiverId, count]
        await Clients.Group($"user:{receiverId}")
            .SendAsync("UnReadMessageCountForUser", eventId, senderId, receiverId, count);
    }

    // Client calls: DeleteUnReadMessages([ids])
    public Task DeleteUnReadMessages(List<int> messageIds)
    {
        var myId = GetUserIdOrThrow();
        var set = messageIds.ToHashSet();

        lock (ChatStore.LockObj)
        {
            for (int i = 0; i < ChatStore.Messages.Count; i++)
            {
                var m = ChatStore.Messages[i];
                if (set.Contains(m.Id) && m.ReceiverId == myId)
                {
                    ChatStore.Messages[i] = m with { IsRead = true };
                }
            }
        }

        return Task.CompletedTask;
    }

    private int GetUserIdOrThrow()
    {
        if (Context.Items.TryGetValue("userId", out var v) && v is int id) return id;
        throw new HubException("Not registered. Call RegisterUser(eventId, userId) first.");
    }


    public override Task OnDisconnectedAsync(Exception? exception)
{
    if (Context.Items.TryGetValue("userId", out var v) && v is int userId)
    {
        lock (ChatStore.LockObj)
        {
            if (ChatStore.OnlineConnections.TryGetValue(userId, out var c))
            {
                c--;
                if (c <= 0) ChatStore.OnlineConnections.Remove(userId);
                else ChatStore.OnlineConnections[userId] = c;
            }
        }
    }
    return base.OnDisconnectedAsync(exception);
}

public async Task RegisterUser(int eventId, int userId)
{
    await Groups.AddToGroupAsync(Context.ConnectionId, $"event:{eventId}");
    await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");

    Context.Items["eventId"] = eventId;
    Context.Items["userId"] = userId;

    lock (ChatStore.LockObj)
    {
        ChatStore.OnlineConnections.TryGetValue(userId, out var c);
        ChatStore.OnlineConnections[userId] = c + 1;
    }
}

}
