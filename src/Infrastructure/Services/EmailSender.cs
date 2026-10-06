using System;
using System.Threading.Tasks;
using Azure;
using Azure.Communication.Email;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Services;

/// <summary>
/// Sends transactional email via Azure Communication Services (Email).
///
/// Required environment variables / Key Vault secrets:
///   ACS_CONNECTION_STRING  – ACS resource connection string
///   ACS_SENDER_ADDRESS     – verified sender e-mail address (e.g. DoNotReply@…azurecomm.net)
///
/// Both values are injected at startup; no secrets are hardcoded here.
/// </summary>
public class EmailSender : IEmailSender
{
    private readonly EmailClient _client;
    private readonly string _senderAddress;
    private readonly ILogger<EmailSender> _logger;

    public EmailSender(ILogger<EmailSender> logger)
    {
        _logger = logger;

        var connectionString = Environment.GetEnvironmentVariable("ACS_CONNECTION_STRING")
            ?? throw new InvalidOperationException(
                "Required environment variable 'ACS_CONNECTION_STRING' is not set. " +
                "Provision the value from Azure Key Vault via Managed Identity.");

        _senderAddress = Environment.GetEnvironmentVariable("ACS_SENDER_ADDRESS")
            ?? throw new InvalidOperationException(
                "Required environment variable 'ACS_SENDER_ADDRESS' is not set. " +
                "Provision the value from Azure Key Vault via Managed Identity.");

        _client = new EmailClient(connectionString);
    }

    /// <summary>
    /// Sends a plain-text / HTML email through Azure Communication Services.
    /// The <paramref name="message"/> parameter is treated as HTML body; a
    /// plain-text fallback is derived by stripping tags naively.
    /// </summary>
    public async Task SendEmailAsync(string email, string subject, string message)
    {
        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException("Recipient address must not be empty.", nameof(email));

        if (string.IsNullOrWhiteSpace(subject))
            throw new ArgumentException("Email subject must not be empty.", nameof(subject));

        var emailMessage = new EmailMessage(
            senderAddress: _senderAddress,
            recipients: new EmailRecipients(
                new[] { new EmailAddress(email) }),
            content: new EmailContent(subject)
            {
                Html      = message,
                PlainText = StripHtml(message)
            });

        try
        {
            EmailSendOperation operation = await _client.SendAsync(
                WaitUntil.Started,   // fire-and-forget style; ACS handles delivery retry
                emailMessage);

            _logger.LogInformation(
                "ACS email enqueued. OperationId={OperationId} Recipient={Recipient} Subject={Subject}",
                operation.Id, email, subject);
        }
        catch (RequestFailedException ex)
        {
            // Log and surface so the caller can decide whether to swallow or rethrow.
            _logger.LogError(ex,
                "ACS email send failed. ErrorCode={ErrorCode} Recipient={Recipient} Subject={Subject}",
                ex.ErrorCode, email, subject);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Unexpected error sending email via ACS. Recipient={Recipient} Subject={Subject}",
                email, subject);
            throw;
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// <summary>
    /// Very simple HTML-tag stripper to produce a plain-text fallback body.
    /// For production usage consider HtmlAgilityPack if richer conversion is needed.
    /// </summary>
    private static string StripHtml(string html)
    {
        if (string.IsNullOrWhiteSpace(html)) return string.Empty;

        // Replace common block-level breaks with newlines then strip remaining tags.
        var text = System.Text.RegularExpressions.Regex.Replace(html, @"<br\s*/?>|</p>|</div>", "\n",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        text = System.Text.RegularExpressions.Regex.Replace(text, "<[^>]+>", string.Empty);

        return System.Net.WebUtility.HtmlDecode(text).Trim();
    }
}
