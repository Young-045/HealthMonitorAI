namespace HealthMonitorAI.Api.Admin;

public interface IAdminCredentialValidator
{
    bool Validate(string username, string password);
    bool IsConfigured { get; }
}
