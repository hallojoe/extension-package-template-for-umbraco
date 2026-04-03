using NUnit.Framework;
using Umbraco.Cms.Tests.Common.Testing;

namespace __TEMPLATE_TESTS_PROJECT_NAMESPACE__.Integration;

[TestFixture]
[UmbracoTest(
    Database = UmbracoTestOptions.Database.NewSchemaPerTest,
    Logger = UmbracoTestOptions.Logger.Console,
    WithApplication = true)]
public class __TEMPLATE_INTEGRATION_TEST_NAME__ : UmbracoTestServerBase
{
    [Test]
    public async Task Ping_ReturnsPong()
    {
        var url = PrepareUrl("/__TEMPLATE_ROUTE_BASE__/ping");
        var response = await Client.GetAsync(url);

        response.EnsureSuccessStatusCode();
        var content = await response.Content.ReadAsStringAsync();

        Assert.That(content, Does.Contain("Pong"));
    }
}
