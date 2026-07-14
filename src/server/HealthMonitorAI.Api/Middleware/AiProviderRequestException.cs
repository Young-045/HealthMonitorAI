namespace HealthMonitorAI.Api.Middleware;

internal sealed class AiProviderRequestException(int upstreamStatusCode) : Exception
{
    internal int UpstreamStatusCode { get; } = upstreamStatusCode;
}
