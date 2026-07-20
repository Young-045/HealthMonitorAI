using HealthMonitorAI.Api.Contracts;
using HealthMonitorAI.Api.Services;
using Microsoft.AspNetCore.Http.HttpResults;

namespace HealthMonitorAI.Api.Endpoints;

internal static class AiEndpoints
{
    internal static WebApplication MapAi(this WebApplication app)
    {
        var group = app.MapGroup("/v1/ai").WithTags("AI");

        group.MapPost("/meal-analysis", async Task<Ok<MealAnalysisResponse>> (
                AnalyzeMealRequest request,
                IAiGateway gateway,
                CancellationToken cancellationToken) =>
            {
                var response = await gateway.AnalyzeMealAsync(request, cancellationToken);
                return TypedResults.Ok(response);
            })
            .WithName("AnalyzeMeal")
            .WithSummary("Analyze a meal using the official AI gateway")
            .WithDescription("Accepts only the current meal input. HealthKit data is not accepted by this endpoint.")
            .Produces<MealAnalysisResponse>(StatusCodes.Status200OK)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status503ServiceUnavailable);

        group.MapGet("/usage", () => TypedResults.Ok(new AiUsageResponse(
                MealAnalysesUsed: 0,
                MealAnalysesLimit: 0,
                PeriodEndsAt: DateTimeOffset.UtcNow.Date.AddDays(1))))
            .WithName("GetAiUsage")
            .WithSummary("Get official AI usage")
            .WithDescription("BYOK calls never pass through this endpoint and do not consume official allowance.")
            .Produces<AiUsageResponse>(StatusCodes.Status200OK);

        return app;
    }
}
