using System;

namespace Microsoft.eShopWeb.PublicApi;

/// <summary>
/// Base class used by API requests and responses — carries a correlation ID
/// that is attached to every structured log line.
/// </summary>
public abstract class BaseMessage
{
    protected Guid _correlationId = Guid.NewGuid();

    public Guid CorrelationId() => _correlationId;
}
