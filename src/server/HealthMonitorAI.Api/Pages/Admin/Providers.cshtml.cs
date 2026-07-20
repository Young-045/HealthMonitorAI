using System.ComponentModel.DataAnnotations;
using HealthMonitorAI.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace HealthMonitorAI.Api.Pages.Admin;

public sealed class ProvidersModel(IOfficialAiConfigurationStore store) : PageModel
{
    [BindProperty]
    public InputModel Input { get; set; } = new();

    public bool ApiKeyConfigured { get; private set; }

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var configuration = await store.GetAsync(cancellationToken);
        ApiKeyConfigured = !string.IsNullOrWhiteSpace(configuration.ApiKey);
        Input = new InputModel
        {
            Enabled = configuration.Enabled,
            ProviderName = configuration.ProviderName,
            BaseUrl = configuration.BaseUrl,
            VisionModel = configuration.VisionModel,
            TextModel = configuration.TextModel
        };
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        var existing = await store.GetAsync(cancellationToken);
        ApiKeyConfigured = !string.IsNullOrWhiteSpace(existing.ApiKey);

        if (!Uri.TryCreate(Input.BaseUrl, UriKind.Absolute, out var baseUri)
            || baseUri.Scheme != Uri.UriSchemeHttps
            || !string.IsNullOrEmpty(baseUri.UserInfo)
            || !string.IsNullOrEmpty(baseUri.Fragment))
        {
            ModelState.AddModelError("Input.BaseUrl", "必须使用不含用户信息和片段的 HTTPS 地址。");
        }

        var apiKey = string.IsNullOrWhiteSpace(Input.ApiKey) ? existing.ApiKey : Input.ApiKey.Trim();
        if (Input.Enabled && string.IsNullOrWhiteSpace(apiKey))
        {
            ModelState.AddModelError("Input.ApiKey", "启用服务前必须配置 API Key。");
        }

        if (!ModelState.IsValid)
        {
            return Page();
        }

        var configuration = new OfficialAiConfiguration(
            Input.Enabled,
            Input.ProviderName.Trim(),
            EnsureTrailingSlash(baseUri!),
            Input.VisionModel.Trim(),
            Input.TextModel.Trim(),
            apiKey,
            DateTimeOffset.UtcNow);
        await store.SaveAsync(configuration, cancellationToken);

        TempData["Saved"] = "AI 服务配置已加密保存。";
        return RedirectToPage();
    }

    private static string EnsureTrailingSlash(Uri uri)
    {
        var value = uri.AbsoluteUri;
        return value.EndsWith("/", StringComparison.Ordinal) ? value : value + "/";
    }

    public sealed class InputModel
    {
        public bool Enabled { get; set; }

        [Required, MaxLength(100)]
        public string ProviderName { get; set; } = "OpenAI Compatible";

        [Required, MaxLength(500)]
        public string BaseUrl { get; set; } = string.Empty;

        [Required, MaxLength(200)]
        public string VisionModel { get; set; } = string.Empty;

        [MaxLength(200)]
        public string TextModel { get; set; } = string.Empty;

        [MaxLength(1_000)]
        public string ApiKey { get; set; } = string.Empty;
    }
}
