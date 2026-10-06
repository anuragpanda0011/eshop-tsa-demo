using System;

namespace BlazorAdmin.Services;

public class CacheEntry<T>
{
    public CacheEntry(T item)
    {
        Value = item;
    }

    public CacheEntry()
    {
    }

    public T Value { get; set; }

    /// <summary>
    /// Always stored as UTC so comparisons across time-zone boundaries are safe.
    /// </summary>
    public DateTime DateCreated { get; set; } = DateTime.UtcNow;
}
