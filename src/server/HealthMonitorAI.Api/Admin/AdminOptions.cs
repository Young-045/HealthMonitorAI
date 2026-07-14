namespace HealthMonitorAI.Api.Admin;

internal sealed class AdminOptions
{
    internal const string SectionName = "Admin";

    public string Username { get; init; } = "admin";
    public string? Password { get; init; }
}
