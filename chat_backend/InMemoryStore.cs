public static class ChatStore
{
    public static readonly object LockObj = new();
    public static int NextId = 1;
    public static readonly List<ChatMessage> Messages = new();
}
