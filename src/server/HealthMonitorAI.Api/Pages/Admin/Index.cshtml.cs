using HealthMonitorAI.Api.Services;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace HealthMonitorAI.Api.Pages.Admin;

public sealed class IndexModel(IOfficialAiConfigurationStore store) : PageModel
{
    public bool IsReady { get; private set; }
    public string ProviderName { get; private set; } = "未配置";
    public string VisionModel { get; private set; } = "未配置";
    public string UpdatedAtText { get; private set; } = "从未";

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var configuration = await store.GetAsync(cancellationToken);
        IsReady = configuration.IsReady;
        ProviderName = string.IsNullOrWhiteSpace(configuration.ProviderName)
            ? "未配置"
            : configuration.ProviderName;
        VisionModel = string.IsNullOrWhiteSpace(configuration.VisionModel)
            ? "未配置"
            : configuration.VisionModel;
        UpdatedAtText = configuration.UpdatedAt == DateTimeOffset.MinValue
            ? "从未"
            : configuration.UpdatedAt.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
    }
}
