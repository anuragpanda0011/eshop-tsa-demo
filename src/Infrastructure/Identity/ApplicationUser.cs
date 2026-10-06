using Microsoft.AspNetCore.Identity;

namespace Microsoft.eShopWeb.Infrastructure.Identity;

public class ApplicationUser : IdentityUser
{
    // ASP.NET Core Identity uses PBKDF2 (with HMACSHA256, 10 000 iterations by
    // default, configurable via PasswordHasherOptions) to store password hashes.
    // No MD5 / SHA-1 / plain-text hashing is used anywhere in this class.
    // The PasswordHash column in AspNetUsers is populated exclusively by
    // IPasswordHasher<ApplicationUser>, which is registered by AddIdentity().
}
