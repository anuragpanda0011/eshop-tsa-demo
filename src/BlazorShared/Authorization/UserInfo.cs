using System.Collections.Generic;

namespace BlazorShared.Authorization;

public class UserInfo
{
    public static readonly UserInfo Anonymous = new UserInfo
    {
        IsAuthenticated = false,
        Claims = new List<ClaimValue>()
    };

    public bool IsAuthenticated { get; set; }
    public string NameClaimType { get; set; } = string.Empty;
    public string RoleClaimType { get; set; } = string.Empty;

    /// <summary>
    /// Short-lived JWT bearer token. Never stored in a persistent store — held only
    /// for the lifetime of the current Blazor circuit / page session.
    /// </summary>
    public string Token { get; set; } = string.Empty;

    public IEnumerable<ClaimValue> Claims { get; set; } = new List<ClaimValue>();

    public bool IsAdministrator()
    {
        foreach (var claim in Claims)
        {
            if (string.Equals(claim.Type, RoleClaimType, StringComparison.OrdinalIgnoreCase) &&
                string.Equals(claim.Value, Constants.Roles.ADMINISTRATORS, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }
        return false;
    }
}
