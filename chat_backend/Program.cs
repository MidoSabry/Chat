using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin()
));

builder.Services.AddSignalR();

// ✅ FCM service
builder.Services.AddHttpClient<FcmService>();

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = null;
});

var app = builder.Build();
app.UseCors();

app.MapHub<ChatHub>("/Chat");

// GET /Chat/getChatMessages?eventId=1&myUserId=10&otherSideId=20
app.MapGet("/Chat/getChatMessages", (int eventId, int myUserId, int? otherSideId) =>
{
    var items = ChatStore.Messages
        .Where(m => m.EventId == eventId)
        .Where(m =>
            otherSideId == null
                ? (m.SenderId == myUserId || m.ReceiverId == myUserId)
                : ((m.SenderId == myUserId && m.ReceiverId == otherSideId) ||
                   (m.SenderId == otherSideId && m.ReceiverId == myUserId))
        )
        .OrderBy(m => m.Id)
        .Select(m => m.ToApiJson())
        .ToList();

    return Results.Ok(new { items });
});

// GET /Chat/GetUnReadMessagesCountForEvent?eventId=1&myUserId=10
app.MapGet("/Chat/GetUnReadMessagesCountForEvent", (int eventId, int myUserId) =>
{
    var items = ChatStore.Messages
        .Where(m => m.EventId == eventId && m.ReceiverId == myUserId && !m.IsRead)
        .GroupBy(m => m.SenderId)
        .Select(g => new { UserId = g.Key, Count = g.Count() })
        .ToList();

    return Results.Ok(new { items });
});

// GET /Chat/GetMyConversations?eventId=1&myUserId=2
app.MapGet("/Chat/GetMyConversations", (int eventId, int myUserId) =>
{
    var related = ChatStore.Messages
        .Where(m => m.EventId == eventId)
        .Where(m => m.SenderId == myUserId || m.ReceiverId == myUserId)
        .ToList();

    var items = related
        .GroupBy(m => m.SenderId == myUserId ? m.ReceiverId : m.SenderId)
        .Select(g =>
        {
            var otherUserId = g.Key;

            var last = g.OrderByDescending(x => x.Id).First();

            var unreadCount = g.Count(x =>
                x.ReceiverId == myUserId &&
                x.SenderId == otherUserId &&
                !x.IsRead
            );

            return new
            {
                UserId = otherUserId,
                LastMessage = last.MessageText,
                LastMessageTime = last.Timestamp,
                UnreadCount = unreadCount
            };
        })
        .OrderByDescending(x => x.LastMessageTime)
        .ToList();

    return Results.Ok(new { items });
});

// ✅ POST /Push/RegisterToken
app.MapPost("/Push/RegisterToken", (PushTokenDto dto) =>
{
    lock (ChatStore.LockObj)
    {
        ChatStore.UserTokens[dto.UserId] = dto.Token;
    }

    return Results.Ok(new { ok = true });
});


// GET /Chat/GetMessagesSince?eventId=1&myUserId=2&otherSideId=5&afterId=120
app.MapGet("/Chat/GetMessagesSince", (int eventId, int myUserId, int otherSideId, int afterId) =>
{
    var items = ChatStore.Messages
        .Where(m => m.EventId == eventId)
        .Where(m => m.Id > afterId)
        .Where(m =>
            (m.SenderId == myUserId && m.ReceiverId == otherSideId) ||
            (m.SenderId == otherSideId && m.ReceiverId == myUserId)
        )
        .OrderBy(m => m.Id)
        .Select(m => m.ToApiJson())
        .ToList();

    return Results.Ok(new { items });
});


app.Run();
