namespace HealthMonitorAI.Api.Middleware;

internal sealed class AiProviderInvalidResponseException : Exception
{
    internal AiProviderInvalidResponseException()
    {
    }

    internal AiProviderInvalidResponseException(Exception innerException)
        : base("The AI provider returned an invalid response.", innerException)
    {
    }
}
