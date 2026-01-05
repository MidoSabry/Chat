public record ChatMessage(
    int Id,
    int EventId,
    int SenderId,
    int ReceiverId,
    string MessageText,
    string Timestamp,
    bool IsRead
)
{
    public object ToApiJson() => new
    {
        Id,
        EventId,
        SenderId,
        ReceiverId,
        MessageText,
        Timestamp,
        IsRead
    };
}
