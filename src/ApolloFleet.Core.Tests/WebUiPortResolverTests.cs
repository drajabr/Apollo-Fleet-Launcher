using Xunit;

namespace ApolloFleet.Core.Tests;

public class WebUiPortResolverTests
{
    [Fact]
    public void HttpsPort_IsStreamingPlusOne()
    {
        Assert.Equal(47991, WebUiPortResolver.GetHttpsPort(47990));
        Assert.Equal("https://localhost:47991", WebUiPortResolver.GetWebUiUrl(47990));
    }
}
