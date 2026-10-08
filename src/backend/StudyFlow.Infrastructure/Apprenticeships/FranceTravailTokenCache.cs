namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed record FranceTravailAccessToken(string Value, DateTimeOffset ExpiresAt);

/// <summary>
/// Le fournisseur France Travail est un client HTTP typé, recréé à chaque requête :
/// le jeton OAuth est donc conservé ici, en singleton, pour ne pas le redemander à chaque recherche.
/// </summary>
public sealed class FranceTravailTokenCache
{
    private static readonly TimeSpan RenewalMargin = TimeSpan.FromMinutes(1);

    private readonly SemaphoreSlim _renewalLock = new(1, 1);
    private volatile FranceTravailAccessToken? _current;

    public async Task<string> GetOrRequestAsync(
        Func<CancellationToken, Task<FranceTravailAccessToken>> requestToken,
        CancellationToken cancellationToken)
    {
        if (IsUsable(_current)) return _current!.Value;

        await _renewalLock.WaitAsync(cancellationToken);
        try
        {
            // Une autre requête a peut-être renouvelé le jeton pendant l'attente.
            if (IsUsable(_current)) return _current!.Value;

            _current = await requestToken(cancellationToken);
            return _current.Value;
        }
        finally
        {
            _renewalLock.Release();
        }
    }

    private static bool IsUsable(FranceTravailAccessToken? token) =>
        token is not null && token.ExpiresAt > DateTimeOffset.UtcNow.Add(RenewalMargin);
}
