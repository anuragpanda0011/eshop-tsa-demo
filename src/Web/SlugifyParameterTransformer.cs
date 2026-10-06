using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Routing;

namespace Microsoft.eShopWeb.Web;

public class SlugifyParameterTransformer : IOutboundParameterTransformer
{
    private static readonly Regex SlugRegex =
        new("([a-z])([A-Z])", RegexOptions.Compiled, TimeSpan.FromMilliseconds(100));

    public string? TransformOutbound(object? value)
    {
        if (value == null) return null;

        var str = value.ToString();
        if (string.IsNullOrEmpty(str)) return null;

        return SlugRegex.Replace(str, "$1-$2").ToLower();
    }
}
