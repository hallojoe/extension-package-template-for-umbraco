using Asp.Versioning;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Umbraco.Cms.Core.Models.Membership;
using Umbraco.Cms.Core.Security;

namespace __TEMPLATE_PROJECTS_NAMESPACE__.Controllers;

[ApiVersion("1.0")]
[ApiExplorerSettings(GroupName = Constants.ApiGroup)]
public class __TEMPLATE_NAMESPACE_COMPACT__ApiController(IBackOfficeSecurityAccessor backOfficeSecurityAccessor) : __TEMPLATE_NAMESPACE_COMPACT__ApiControllerBase
{
    [HttpGet("ping")]
    [ProducesResponseType<string>(StatusCodes.Status200OK)]
    public string Ping() => "Pong";

    [HttpGet("whatsTheTimeMrWolf")]
    [ProducesResponseType(typeof(DateTime), 200)]
    public DateTime WhatsTheTimeMrWolf() => DateTime.Now;

    [HttpGet("whatsMyName")]
    [ProducesResponseType<string>(StatusCodes.Status200OK)]
    public string WhatsMyName()
    {
        // So we can see a long request in the dashboard with a spinning progress wheel
        Thread.Sleep(2000);

        var currentUser = backOfficeSecurityAccessor.BackOfficeSecurity?.CurrentUser;
        return currentUser?.Name ?? "I have no idea who you are";
    }

    [HttpGet("whoAmI")]
    [ProducesResponseType<IUser>(StatusCodes.Status200OK)]
    public IUser? WhoAmI() => backOfficeSecurityAccessor.BackOfficeSecurity?.CurrentUser;
}


