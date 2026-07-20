using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using HealthMonitorAI.Api.Admin;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace HealthMonitorAI.Api.Pages.Admin;

[AllowAnonymous]
public sealed class LoginModel(IAdminCredentialValidator credentialValidator) : PageModel
{
    [BindProperty, Required, MaxLength(100)]
    public string Username { get; set; } = string.Empty;

    [BindProperty, Required, MaxLength(500)]
    public string Password { get; set; } = string.Empty;

    [BindProperty]
    public string? ReturnUrl { get; set; }

    public IActionResult OnGet(string? returnUrl)
    {
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToPage("/Admin/Index");
        }

        ReturnUrl = returnUrl;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        if (!credentialValidator.IsConfigured)
        {
            ModelState.AddModelError(string.Empty, "后台尚未配置。请设置至少12位的 Admin__Password 环境变量。");
            return Page();
        }

        if (!credentialValidator.Validate(Username, Password))
        {
            ModelState.AddModelError(string.Empty, "用户名或密码错误。");
            return Page();
        }

        var identity = new ClaimsIdentity(
            [
                new Claim(ClaimTypes.Name, Username),
                new Claim(ClaimTypes.Role, "Admin")
            ],
            CookieAuthenticationDefaults.AuthenticationScheme);
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identity));

        return Url.IsLocalUrl(ReturnUrl)
            ? LocalRedirect(ReturnUrl!)
            : RedirectToPage("/Admin/Index");
    }

    public async Task<IActionResult> OnPostLogoutAsync()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return RedirectToPage("/Admin/Login");
    }
}
