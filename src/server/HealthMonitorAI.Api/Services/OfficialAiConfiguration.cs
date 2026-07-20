namespace HealthMonitorAI.Api.Services;

public sealed record OfficialAiConfiguration(
    bool Enabled,
    string ProviderName,
    string BaseUrl,
    string VisionModel,
    string TextModel,
    string ApiKey,
    DateTimeOffset UpdatedAt)
{
    public static OfficialAiConfiguration Empty { get; } = new(
        false,
        "OpenAI Compatible",
        string.Empty,
        string.Empty,
        string.Empty,
        string.Empty,
        DateTimeOffset.MinValue);

    public bool IsReady => Enabled
        && Uri.TryCreate(BaseUrl, UriKind.Absolute, out var uri)
        && uri.Scheme == Uri.UriSchemeHttps
        && !string.IsNullOrWhiteSpace(VisionModel)
        && !string.IsNullOrWhiteSpace(ApiKey);
}
