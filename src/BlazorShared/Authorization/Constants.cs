namespace BlazorShared.Authorization;

public static class Constants
{
    public static class Roles
    {
        public const string ADMINISTRATORS = "Administrators";
    }

    public static class ClaimTypes
    {
        public const string Role = "role";
        public const string Name = "name";
    }

    public static class Policies
    {
        public const string AdminOnly = "AdminOnly";
    }
}
