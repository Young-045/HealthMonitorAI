using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace HealthMonitorAI.Api.Middleware;

internal sealed class ApiExceptionHandler(ILogger<ApiExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var error = exception switch
        {
            ArgumentException => new ApiError(400, "INVALID_REQUEST", "The request is invalid."),
            AiProviderNotConfiguredException => new ApiError(
                503,
                "AI_PROVIDER_NOT_CONFIGURED",
                "The official AI provider is not configured."),
            _ => null
        };

        if (error is null)
        {
            return false;
        }

        logger.LogWarning(exception, "Handled API error {ErrorCode}", error.Code);
        httpContext.Response.StatusCode = error.StatusCode;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = error.StatusCode,
            Title = error.Code,
            Detail = error.Detail,
            Instance = httpContext.Request.Path
        }, cancellationToken);

        return true;
    }

    private sealed record ApiError(int StatusCode, string Code, string Detail);
}
