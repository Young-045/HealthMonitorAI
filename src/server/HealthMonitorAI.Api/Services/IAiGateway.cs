using HealthMonitorAI.Api.Contracts;

namespace HealthMonitorAI.Api.Services;

public interface IAiGateway
{
    Task<MealAnalysisResponse> AnalyzeMealAsync(
        AnalyzeMealRequest request,
        CancellationToken cancellationToken);
}
