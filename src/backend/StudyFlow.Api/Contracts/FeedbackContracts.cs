using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

/// <param name="Kind">« idea » ou « bug ».</param>
public sealed record FeedbackRequest(
    [StringLength(10)] string Kind,
    [StringLength(4000, ErrorMessage = "Message : 4000 caractères maximum.")] string Message,
    [StringLength(30)] string? AppVersion = null,
    [StringLength(20)] string? Platform = null);
