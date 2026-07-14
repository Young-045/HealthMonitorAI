using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace HealthMonitorAI.Api.Admin;

internal sealed class AdminCredentialValidator(IOptions<AdminOptions> options) : IAdminCredentialValidator
{
    private readonly AdminOptions options = options.Value;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Username)
        && !string.IsNullOrWhiteSpace(options.Password)
        && options.Password.Length >= 12;

    public bool Validate(string username, string password)
    {
        if (!IsConfigured)
        {
            return false;
        }

        return FixedTimeEquals(username, options.Username)
            && FixedTimeEquals(password, options.Password!);
    }

    private static bool FixedTimeEquals(string supplied, string expected)
    {
        var suppliedBytes = Encoding.UTF8.GetBytes(supplied);
        var expectedBytes = Encoding.UTF8.GetBytes(expected);
        return suppliedBytes.Length == expectedBytes.Length
            && CryptographicOperations.FixedTimeEquals(suppliedBytes, expectedBytes);
    }
}
