public static class ChatStore
{
    public static readonly object LockObj = new();
    public static int NextId = 1;
    public static readonly List<ChatMessage> Messages = new();
    // ✅ userId -> FCM token
    public static readonly Dictionary<int, string> UserTokens = new();
     // ✅ online users
    public static readonly Dictionary<int, int> OnlineConnections = new(); // userId -> connectionCount
}
