using System;

namespace BlazorShared.Attributes;

[AttributeUsage(AttributeTargets.Class, AllowMultiple = false, Inherited = true)]
public class EndpointAttribute : Attribute
{
    public string Name { get; set; } = string.Empty;
}
