using System.Collections.Generic;

namespace BlazorShared.Authorization;

public class UserInfo
{
    public static readonly UserInfo Anonymous = new UserInfo();

    public bool IsAuthenticated { get; set; }
    public string NameClaimType { get; set; }
    public string RoleClaimType { get; set; }

    /// <summary>
    /// Bearer token — never log or persist this value.
    /// </summary>
    public string Token { get; set; }

    public IEnumerable<ClaimValue> Claims { get; set; } = new List<ClaimValue>();
}
