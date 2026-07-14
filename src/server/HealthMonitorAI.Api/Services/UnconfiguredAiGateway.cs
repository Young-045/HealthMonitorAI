using HealthMonitorAI.Api.Contracts;
using HealthMonitorAI.Api.Middleware;

namespace HealthMonitorAI.Api.Services;

internal sealed class UnconfiguredAiGateway : IAiGateway
{
    public Task<MealAnalysisResponse> AnalyzeMealAsync(
        AnalyzeMealRequest request,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (request.Image is null && string.IsNullOrWhiteSpace(request.Description))
        {
            throw new ArgumentException("A meal image or description is required.");
        }

        throw new AiProviderNotConfiguredException();
    }
}
