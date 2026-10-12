namespace StudyFlow.Api.Contracts;

/// <summary>Un compte du seed, pour la connexion en un geste de l'app de dev.</summary>
public sealed record DevelopmentAccountResponse(
    string Email,
    string Password,
    string FirstName,
    string LastName,
    string Situation,
    string Details,
    bool IsDelegate,
    bool HasClass,
    bool FirstLaunch);
