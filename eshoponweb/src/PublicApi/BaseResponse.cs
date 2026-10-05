using System;

namespace Microsoft.eShopWeb.PublicApi;

/// <summary>
/// Base class used by API responses.
/// </summary>
public abstract class BaseResponse : BaseMessage
{
    protected BaseResponse(Guid correlationId) : base()
    {
        base._correlationId = correlationId;
    }

    protected BaseResponse()
    {
    }
}
