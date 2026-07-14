using HealthMonitorAI.Api.Contracts;

namespace HealthMonitorAI.Api.Endpoints;

internal static class ConfigurationEndpoints
{
    internal static WebApplication MapConfiguration(this WebApplication app)
    {
        app.MapGet("/v1/config", () => TypedResults.Ok(new AppConfigurationResponse(
                ApiVersion: "1.0",
                MealAnalysisSchemaVersion: "1.0",
                OfficialAiAvailable: false,
                MaximumImageBytes: 5 * 1024 * 1024,
                SupportedImageContentTypes: ["image/jpeg", "image/png", "image/heic"])))
            .WithName("GetAppConfiguration")
            .WithSummary("Get public client configuration")
            .WithDescription("Returns API capabilities without exposing provider names or secrets.")
            .Produces<AppConfigurationResponse>(StatusCodes.Status200OK);

        return app;
    }
}
