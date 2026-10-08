using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using StudyFlow.Infrastructure.Identity;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Helpers communs aux contrôleurs authentifiés. L'utilisateur chargé par la validation
/// du jeton reste suivi par le DbContext de la requête : <see cref="CurrentUserAsync"/>
/// le retrouve sans nouvelle requête SQL.
/// </summary>
public abstract class StudyFlowControllerBase(UserManager<ApplicationUser> userManager) : ControllerBase
{
    protected UserManager<ApplicationUser> UserManager { get; } = userManager;

    protected Guid CurrentUserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    protected Task<ApplicationUser?> CurrentUserAsync() => UserManager.FindByIdAsync(CurrentUserId.ToString());

    protected ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });

    protected ObjectResult ConflictProblem(string title, string? detail = null) =>
        Conflict(new ProblemDetails { Title = title, Detail = detail, Status = StatusCodes.Status409Conflict });

    protected ActionResult IdentityValidationProblem(IdentityResult result) =>
        ValidationProblem(new ValidationProblemDetails(result.Errors
            .GroupBy(x => x.Code)
            .ToDictionary(x => x.Key, x => x.Select(error => error.Description).ToArray())));
}
