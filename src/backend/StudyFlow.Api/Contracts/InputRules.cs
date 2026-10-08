using System.Text.RegularExpressions;

namespace StudyFlow.Api.Contracts;

public static partial class InputRules
{
    public const int UrlMaxLength = 2048;
    public const string SchoolYearPattern = @"^\d{4}-\d{4}$";
    public const string SchoolYearMessage = "L'année scolaire doit être au format 2026-2027.";

    /// <summary>Seuls les liens web sont acceptés : un lien javascript: ou file: serait ouvert par l'application.</summary>
    public static bool IsWebUrl(string? value) =>
        Uri.TryCreate(value?.Trim(), UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp);

    public static bool IsSchoolYear(string value) => SchoolYearRegex().IsMatch(value);

    [GeneratedRegex(SchoolYearPattern)]
    private static partial Regex SchoolYearRegex();
}
