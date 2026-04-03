using System.IO;
using NUnit.Framework;

namespace __TEMPLATE_TESTS_PROJECT_NAMESPACE__;

[SetUpFixture]
public sealed class TestAssemblySetup
{
    private static GlobalSetupTeardown? _setup;

    [OneTimeSetUp]
    public void AssemblyInitialize()
    {
        EnsureTestDirectories();
        _setup = new GlobalSetupTeardown();
        _setup.SetUp();
    }

    [OneTimeTearDown]
    public void AssemblyCleanup()
    {
        _setup?.TearDown();
    }

    private static void EnsureTestDirectories()
    {
        var testProjectRoot = Path.GetFullPath(
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
        CreateTempTree(testProjectRoot);
    }

    private static void CreateTempTree(string basePath)
    {
        var root = Path.Combine(basePath, "TEMP");
        Directory.CreateDirectory(root);
        Directory.CreateDirectory(Path.Combine(root, "media"));
        Directory.CreateDirectory(Path.Combine(root, "cache"));
        Directory.CreateDirectory(Path.Combine(root, "logs"));
        Directory.CreateDirectory(Path.Combine(root, "databases"));
    }
}
