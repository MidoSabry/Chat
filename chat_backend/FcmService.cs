using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Google.Apis.Auth.OAuth2;

public class FcmService
{
    private readonly HttpClient _http;
    private readonly string _projectId;
    private readonly GoogleCredential _credential;

    public FcmService(HttpClient http, IConfiguration config)
    {
        _http = http;

        _projectId = config["Fcm:ProjectId"]
            ?? throw new Exception("Missing config: Fcm:ProjectId");

        var saPath = config["Fcm:ServiceAccountPath"]
            ?? throw new Exception("Missing config: Fcm:ServiceAccountPath");

        _credential = GoogleCredential.FromFile(saPath)
            .CreateScoped("https://www.googleapis.com/auth/firebase.messaging");
    }

    public async Task SendToTokenAsync(
        string token,
        string title,
        string body,
        Dictionary<string, string>? data = null
    )
    {
        var accessToken = await _credential.UnderlyingCredential
            .GetAccessTokenForRequestAsync();

        using var req = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://fcm.googleapis.com/v1/projects/{_projectId}/messages:send"
        );

        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var payload = new
        {
            message = new
            {
                token = token,
                notification = new { title, body },
                data = data ?? new Dictionary<string, string>()
            }
        };

        req.Content = new StringContent(
            JsonSerializer.Serialize(payload),
            Encoding.UTF8,
            "application/json"
        );

        var res = await _http.SendAsync(req);
        if (!res.IsSuccessStatusCode)
        {
            var err = await res.Content.ReadAsStringAsync();
            throw new Exception($"FCM send failed: {(int)res.StatusCode} {res.StatusCode} - {err}");
        }
    }
}
