namespace HealthMonitorAI.Api.Contracts;

/// <summary>Describes the public capabilities and contract versions supported by the API.</summary>
public sealed record AppConfigurationResponse(
    string ApiVersion,
    string MealAnalysisSchemaVersion,
    bool OfficialAiAvailable,
    int MaximumImageBytes,
    IReadOnlyList<string> SupportedImageContentTypes);
