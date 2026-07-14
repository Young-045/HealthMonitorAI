using System.Text.Json;
using Microsoft.AspNetCore.DataProtection;

namespace HealthMonitorAI.Api.Services;

internal sealed class EncryptedFileOfficialAiConfigurationStore : IOfficialAiConfigurationStore
{
    private readonly IDataProtector protector;
    private readonly ILogger<EncryptedFileOfficialAiConfigurationStore> logger;
    private readonly string filePath;
    private readonly SemaphoreSlim gate = new(1, 1);

    public EncryptedFileOfficialAiConfigurationStore(
        IDataProtectionProvider dataProtectionProvider,
        IWebHostEnvironment environment,
        ILogger<EncryptedFileOfficialAiConfigurationStore> logger)
    {
        protector = dataProtectionProvider.CreateProtector("HealthMonitorAI.OfficialAI.v1");
        this.logger = logger;
        filePath = Path.Combine(environment.ContentRootPath, "App_Data", "official-ai-config.protected");
    }

    public async Task<OfficialAiConfiguration> GetAsync(CancellationToken cancellationToken)
    {
        await gate.WaitAsync(cancellationToken);
        try
        {
            if (!File.Exists(filePath))
            {
                return OfficialAiConfiguration.Empty;
            }

            var protectedValue = await File.ReadAllTextAsync(filePath, cancellationToken);
            var json = protector.Unprotect(protectedValue);
            return JsonSerializer.Deserialize<OfficialAiConfiguration>(json)
                ?? OfficialAiConfiguration.Empty;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Unable to read the encrypted official AI configuration.");
            throw new InvalidOperationException("The encrypted AI configuration cannot be read.");
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task SaveAsync(
        OfficialAiConfiguration configuration,
        CancellationToken cancellationToken)
    {
        await gate.WaitAsync(cancellationToken);
        try
        {
            var directory = Path.GetDirectoryName(filePath)!;
            Directory.CreateDirectory(directory);

            var json = JsonSerializer.Serialize(configuration);
            var protectedValue = protector.Protect(json);
            var temporaryPath = filePath + ".tmp";

            await File.WriteAllTextAsync(temporaryPath, protectedValue, cancellationToken);
            File.Move(temporaryPath, filePath, overwrite: true);
        }
        finally
        {
            gate.Release();
        }
    }
}
