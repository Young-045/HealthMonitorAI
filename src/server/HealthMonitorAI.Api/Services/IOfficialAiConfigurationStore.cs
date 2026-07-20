namespace HealthMonitorAI.Api.Services;

public interface IOfficialAiConfigurationStore
{
    Task<OfficialAiConfiguration> GetAsync(CancellationToken cancellationToken);
    Task SaveAsync(OfficialAiConfiguration configuration, CancellationToken cancellationToken);
}
