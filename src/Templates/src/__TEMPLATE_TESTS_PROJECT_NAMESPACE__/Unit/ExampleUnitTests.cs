using Microsoft.AspNetCore.Mvc;
using NUnit.Framework;

namespace __TEMPLATE_TESTS_PROJECT_NAMESPACE__.Unit;

[TestFixture]
public class ExampleUnitTests
{
    [Test]
    public void EmptyExample_ReturnsOk()
    {
        var result = new OkResult();

        Assert.That(result.StatusCode, Is.EqualTo(200));
    }
}
