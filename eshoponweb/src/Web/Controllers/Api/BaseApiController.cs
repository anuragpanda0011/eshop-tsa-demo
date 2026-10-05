using Microsoft.AspNetCore.Mvc;

namespace Microsoft.eShopWeb.Web.Controllers.Api;

// No longer used — shown for reference only if using full controllers
// instead of Endpoints for APIs.
// All new API routes are registered under /api/v1/ via MinimalApi.Endpoint.
[Route("api/v1/[controller]/[action]")]
[ApiController]
public class BaseApiController : ControllerBase
{
}
