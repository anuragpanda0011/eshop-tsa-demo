using Microsoft.AspNetCore.Mvc;

namespace Microsoft.eShopWeb.Web.Controllers.Api;

// Retained for reference. Active API endpoints use minimal-API pattern under /api/v1/.
[Route("api/v1/[controller]/[action]")]
[ApiController]
public class BaseApiController : ControllerBase
{ }
