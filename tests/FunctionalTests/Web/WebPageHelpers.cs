using System.Text.RegularExpressions;

namespace Microsoft.eShopWeb.FunctionalTests.Web;

public static class WebPageHelpers
{
    public static readonly string TokenTag = "__RequestVerificationToken";

    // Pre-compiled regexes for performance and correctness.
    private static readonly Regex TokenRegex = new(
        @"name=""__RequestVerificationToken"" type=""hidden"" value=""([-A-Za-z0-9+=/\\_]+?)""",
        RegexOptions.Compiled);

    private static readonly Regex IdRegex = new(
        @"name=""Items\[0\].Id"" value=""(\d+)""",
        RegexOptions.Compiled);

    public static string GetRequestVerificationToken(string input) =>
        RegexSearch(TokenRegex, input);

    public static string GetId(string input) =>
        RegexSearch(IdRegex, input);

    private static string RegexSearch(Regex regex, string input)
    {
        var match = regex.Match(input);
        // Return empty string rather than throw if not found; callers assert on length.
        return match.Groups.Values.LastOrDefault()?.Value ?? string.Empty;
    }
}
