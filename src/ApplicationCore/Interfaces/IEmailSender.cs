using System.Threading.Tasks;

namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

public interface IEmailSender
{
    /// <summary>
    /// Sends a transactional email via Azure Communication Services.
    /// </summary>
    /// <param name="email">Recipient email address.</param>
    /// <param name="subject">Email subject line.</param>
    /// <param name="message">HTML or plain-text body.</param>
    Task SendEmailAsync(string email, string subject, string message);
}
