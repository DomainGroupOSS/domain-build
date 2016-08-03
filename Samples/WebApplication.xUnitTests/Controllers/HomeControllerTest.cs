using System.Web.Mvc;
using WebApplication.Controllers;
using Xunit;

namespace WebApplication.xUnitTests.Controllers
{
    public class HomeControllerTest
    {
        [Fact]
        public void Contact()
        {
            // Arrange
            HomeController controller = new HomeController();

            // Act
            ViewResult result = controller.Contact() as ViewResult;

            // Assert
            Assert.NotNull(result);
        }
    }
}
