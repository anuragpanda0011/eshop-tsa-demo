namespace BlazorShared.Authorization;

public class ClaimValue
{
    public ClaimValue()
    {
    }

    public ClaimValue(string type, string value)
    {
        if (string.IsNullOrWhiteSpace(type)) throw new ArgumentException("Claim type must not be empty.", nameof(type));
        if (string.IsNullOrWhiteSpace(value)) throw new ArgumentException("Claim value must not be empty.", nameof(value));

        Type = type;
        Value = value;
    }

    public string Type { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}
