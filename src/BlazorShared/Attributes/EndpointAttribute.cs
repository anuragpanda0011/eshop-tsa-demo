using System;

namespace BlazorShared.Attributes;

[AttributeUsage(AttributeTargets.Class, AllowMultiple = false, Inherited = false)]
public class EndpointAttribute : Attribute
{
    public string Name { get; set; }
}
