using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize(Roles = nameof(UserRole.Delegue))]
[Route("api/v1/delegate/membership-requests")]
public sealed class DelegateMembershipController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<PendingMembershipResponse>>> Pending(CancellationToken cancellationToken)
    {
        var classId = await CurrentDelegateClassId(cancellationToken);
        if (classId is null) return Forbid();

        var requests = await (
            from request in dbContext.ClassMembershipRequests.AsNoTracking()
            join user in dbContext.Users.AsNoTracking() on request.UserId equals user.Id
            where request.SchoolClassId == classId && request.Status == ClassMembershipRequestStatus.Pending
            orderby request.RequestedAt
            select new PendingMembershipResponse(
                request.Id, user.Id, user.FirstName, user.LastName, user.Email ?? string.Empty, request.RequestedAt))
            .ToListAsync(cancellationToken);

        return Ok(requests);
    }

    [HttpPost("{id:guid}/approve")]
    public async Task<IActionResult> Approve(Guid id, CancellationToken cancellationToken)
    {
        var classId = await CurrentDelegateClassId(cancellationToken);
        if (classId is null) return Forbid();

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var request = await dbContext.ClassMembershipRequests
            .SingleOrDefaultAsync(x => x.Id == id && x.SchoolClassId == classId, cancellationToken);
        if (request is null) return NotFound();
        if (request.Status != ClassMembershipRequestStatus.Pending) return ConflictProblem("Cette demande a deja ete traitee.");

        var student = await userManager.FindByIdAsync(request.UserId.ToString());
        if (student is null) return NotFound();
        if (student.SchoolClassId is not null) return ConflictProblem("Cet eleve appartient deja a une classe.");

        student.SchoolClassId = classId;
        student.UpdatedAt = DateTimeOffset.UtcNow;
        request.Status = ClassMembershipRequestStatus.Approved;
        request.DecidedAt = DateTimeOffset.UtcNow;
        request.DecidedById = CurrentUserId();

        var roleResult = await userManager.AddToRoleAsync(student, nameof(UserRole.Eleve));
        if (!roleResult.Succeeded)
        {
            return ValidationProblem(new ValidationProblemDetails(roleResult.Errors
                .GroupBy(x => x.Code)
                .ToDictionary(x => x.Key, x => x.Select(error => error.Description).ToArray())));
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await userManager.UpdateSecurityStampAsync(student);
        await transaction.CommitAsync(cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/reject")]
    public async Task<IActionResult> Reject(Guid id, CancellationToken cancellationToken)
    {
        var classId = await CurrentDelegateClassId(cancellationToken);
        if (classId is null) return Forbid();

        var request = await dbContext.ClassMembershipRequests
            .SingleOrDefaultAsync(x => x.Id == id && x.SchoolClassId == classId, cancellationToken);
        if (request is null) return NotFound();
        if (request.Status != ClassMembershipRequestStatus.Pending) return ConflictProblem("Cette demande a deja ete traitee.");

        request.Status = ClassMembershipRequestStatus.Rejected;
        request.DecidedAt = DateTimeOffset.UtcNow;
        request.DecidedById = CurrentUserId();
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private async Task<Guid?> CurrentDelegateClassId(CancellationToken cancellationToken) =>
        await dbContext.Users
            .Where(x => x.Id == CurrentUserId())
            .Select(x => x.SchoolClassId)
            .SingleOrDefaultAsync(cancellationToken);

    private Guid CurrentUserId() => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private ObjectResult ConflictProblem(string title) =>
        Conflict(new ProblemDetails { Title = title, Status = StatusCodes.Status409Conflict });
}
