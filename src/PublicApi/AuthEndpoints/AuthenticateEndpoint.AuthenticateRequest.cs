using System.ComponentModel.DataAnnotations;

namespace Microsoft.eShopWeb.PublicApi.AuthEndpoints;

public class AuthenticateRequest : BaseRequest
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}
