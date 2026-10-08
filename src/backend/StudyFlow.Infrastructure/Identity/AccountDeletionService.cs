using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Application.Accounts;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Identity;

public sealed class AccountDeletionService(
    StudyFlowDbContext dbContext,
    UserManager<ApplicationUser> userManager) : IAccountDeletionService
{
    public async Task<AccountDeletionResult> DeleteAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null || !user.IsActive) return AccountDeletionResult.NotFound;

        if (user.SchoolClassId is { } classId)
        {
            var otherMembersCount = await dbContext.Users
                .CountAsync(x => x.SchoolClassId == classId && x.IsActive && x.Id != userId, cancellationToken);
            var isDelegate = await userManager.IsInRoleAsync(user, nameof(UserRole.Delegue));

            if (isDelegate && otherMembersCount > 0)
            {
                var otherDelegateExists = await dbContext.ActiveDelegatesOfClass(classId)
                    .AnyAsync(x => x.Id != userId, cancellationToken);
                if (!otherDelegateExists) return AccountDeletionResult.LastDelegate;
            }

            if (otherMembersCount == 0)
            {
                // Une classe sans membre ne doit plus accepter de demandes que personne ne pourra valider.
                await dbContext.SchoolClasses
                    .Where(x => x.Id == classId)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(x => x.IsActive, false)
                        .SetProperty(x => x.UpdatedAt, DateTimeOffset.UtcNow), cancellationToken);
            }
        }

        await DeletePersonalDataAsync(userId, cancellationToken);
        await AnonymizeAccountAsync(user, cancellationToken);

        await transaction.CommitAsync(cancellationToken);
        return AccountDeletionResult.Deleted;
    }

    private async Task DeletePersonalDataAsync(Guid userId, CancellationToken cancellationToken)
    {
        // Données strictement personnelles : elles disparaissent avec le compte.
        await dbContext.PersonalTasks.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.PersonalEvents.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.HomeworkProgressItems.IgnoreQueryFilters().Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.ApprenticeshipSearches.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.FavoriteOffers.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.NotificationDevices.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.NotificationPreferences.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.NotificationDeliveries.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.UserAppSettings.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.ClassMembershipRequests.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.RefreshTokens.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.PasswordResetTokens.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.UserClaims.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.UserLogins.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.UserTokens.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);
        await dbContext.UserRoles.Where(x => x.UserId == userId).ExecuteDeleteAsync(cancellationToken);

        // Les messages d'entraide peuvent contenir des contacts : ils sont supprimés, pas seulement masqués.
        await dbContext.ApprenticeshipMessages
            .IgnoreQueryFilters()
            .Where(x => x.AuthorId == userId)
            .ExecuteDeleteAsync(cancellationToken);
    }

    private async Task AnonymizeAccountAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        // Les cours, devoirs et annonces restent à la classe : la ligne utilisateur sert
        // seulement de référence anonyme pour leurs auteurs.
        var anonymousLogin = $"deleted-{user.Id:N}@deleted.invalid";
        user.Email = anonymousLogin;
        user.UserName = anonymousLogin;
        user.EmailConfirmed = false;
        user.PasswordHash = null;
        user.PhoneNumber = null;
        user.PhoneNumberConfirmed = false;
        user.TwoFactorEnabled = false;
        user.FirstName = "Compte";
        user.LastName = "supprimé";
        user.SchoolClassId = null;
        user.IsActive = false;
        user.UpdatedAt = DateTimeOffset.UtcNow;

        // UpdateSecurityStampAsync enregistre aussi l'utilisateur et invalide les access tokens encore valides.
        var result = await userManager.UpdateSecurityStampAsync(user);
        if (!result.Succeeded)
        {
            throw new InvalidOperationException(
                $"Anonymisation du compte impossible : {string.Join(", ", result.Errors.Select(x => x.Code))}");
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
