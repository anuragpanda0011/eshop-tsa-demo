using System;
using System.Threading.Tasks;
using Azure;
using Azure.Communication.Email;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Services;

/// <summary>
/// Sends transactional email via Azure Communication Services Email.
/// Required environment variables:
///   ACS_CONNECTION_STRING  – ACS resource connection string (from Key Vault in production)
///   ACS_SENDER_ADDRESS     – verified sender e-mail address (e.g. DoNotReply@yourdomain.azurecomm.net)
/// </summary>
public class EmailSender : IEmailSender
{
    private readonly EmailClient _emailClient;
    private readonly string _senderAddress;
    private readonly ILogger<EmailSender> _logger;

    public EmailSender(ILogger<EmailSender> logger)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        var connectionString = Environment.GetEnvironmentVariable("ACS_CONNECTION_STRING")
            ?? throw new InvalidOperationException(
                "Required environment variable 'ACS_CONNECTION_STRING' is not set. " +
                "In production this value is injected from Azure Key Vault via Managed Identity.");

        _senderAddress = Environment.GetEnvironmentVariable("ACS_SENDER_ADDRESS")
            ?? throw new InvalidOperationException(
                "Required environment variable 'ACS_SENDER_ADDRESS' is not set.");

        _emailClient = new EmailClient(connectionString);
    }

    /// <summary>
    /// Sends an email using Azure Communication Services.
    /// The call is best-effort: if delivery fails we log the error but do not throw,
    /// so that the caller's business operation is not blocked by email failures.
    /// </summary>
    public async Task SendEmailAsync(string email, string subject, string message)
    {
        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException("Recipient email address must not be empty.", nameof(email));
        if (string.IsNullOrWhiteSpace(subject))
            throw new ArgumentException("Email subject must not be empty.", nameof(subject));

        try
        {
            var emailMessage = new EmailMessage(
                senderAddress: _senderAddress,
                recipients: new EmailRecipients(
                    new[] { new EmailAddress(email) }),
                content: new EmailContent(subject)
                {
                    Html = message,
                    PlainText = System.Text.RegularExpressions.Regex.Replace(message, "<[^>]*>", string.Empty)
                });

            EmailSendOperation sendOperation = await _emailClient.SendAsync(
                WaitUntil.Started,
                emailMessage);

            _logger.LogInformation(
                System.Text.Json.JsonSerializer.Serialize(new
                {
                    timestamp = DateTimeOffset.UtcNow.ToString("o"),
                    traceId   = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? string.Empty,
                    @event    = "EmailSent",
                    operationId = sendOperation.Id,
                    recipient = email,
                    subject
                }));
        }
        catch (Exception ex)
        {
            // Best-effort: log but do not rethrow so that the caller continues.
            _logger.LogError(
                System.Text.Json.JsonSerializer.Serialize(new
                {
                    timestamp = DateTimeOffset.UtcNow.ToString("o"),
                    traceId   = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? string.Empty,
                    @event    = "EmailSendFailed",
                    recipient = email,
                    subject,
                    error     = ex.Message
                }));
        }
    }
}
