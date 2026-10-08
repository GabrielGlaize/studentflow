using System.Security.Cryptography;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace StudyFlow.Api;

/// <summary>
/// Transforme les erreurs techniques prévisibles en réponses compréhensibles au lieu d'un 500 muet.
/// </summary>
public sealed class StudyFlowExceptionHandler(ILogger<StudyFlowExceptionHandler> logger) : IExceptionHandler
{
    private const string UniqueViolationSqlState = "23505";

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var problem = exception switch
        {
            DbUpdateConcurrencyException => new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "Cette donnée a été modifiée entre-temps.",
                Detail = "Recharge la page puis recommence."
            },
            DbUpdateException { InnerException: PostgresException { SqlState: UniqueViolationSqlState } } => new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "Cet élément existe déjà."
            },
            _ => null
        };

        if (exception is CryptographicException)
        {
            // Presque toujours un dossier de clés DataProtection perdu ou différent entre deux déploiements.
            logger.LogCritical(
                exception,
                "Impossible de déchiffrer une donnée : vérifie Security:DataProtectionKeysPath et la sauvegarde des clés.");
        }

        if (problem is null) return false;

        httpContext.Response.StatusCode = problem.Status!.Value;
        await httpContext.Response.WriteAsJsonAsync(problem, cancellationToken);
        return true;
    }
}
