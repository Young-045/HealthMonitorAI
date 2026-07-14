namespace HealthMonitorAI.Api.Endpoints;

internal static class HealthEndpoints
{
    internal static WebApplication MapHealth(this WebApplication app)
    {
        app.MapGet("/health", () => TypedResults.Ok(new
            {
                status = "healthy",
                timestamp = DateTimeOffset.UtcNow
            }))
            .WithName("GetHealth")
            .WithSummary("Check API health")
            .WithDescription("Returns a small liveness response without accessing AI or user data.")
            .Produces(StatusCodes.Status200OK);

        return app;
    }
}
