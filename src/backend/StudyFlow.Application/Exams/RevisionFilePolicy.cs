using System.Text;

namespace StudyFlow.Application.Exams;

/// <summary>
/// Liste blanche des fichiers acceptés dans les fiches de révision. Le type est déduit du
/// contenu (signature des premiers octets), pas seulement de l'extension : un .exe renommé
/// en .pdf est refusé. Tout ce qui n'est pas explicitement autorisé est refusé.
/// </summary>
public static class RevisionFilePolicy
{
    public const int MaxFileNameLength = 120;
    public const long MaxUploadBytes = 10 * 1024 * 1024;

    private static readonly Dictionary<string, AllowedFormat> AllowedByExtension = new()
    {
        [".pdf"] = AllowedFormat.Pdf,
        [".png"] = AllowedFormat.Png,
        [".jpg"] = AllowedFormat.Jpeg,
        [".jpeg"] = AllowedFormat.Jpeg,
        [".webp"] = AllowedFormat.Webp,
        [".html"] = AllowedFormat.Html,
        [".htm"] = AllowedFormat.Html,
        [".txt"] = AllowedFormat.Text,
        [".md"] = AllowedFormat.Text
    };

    // Exécutables, scripts, installeurs, images disque et archives (qui peuvent les cacher).
    private static readonly HashSet<string> BlockedExtensions =
    [
        ".exe", ".msi", ".msix", ".bat", ".cmd", ".com", ".scr", ".pif", ".cpl", ".dll", ".sys",
        ".ps1", ".psm1", ".vbs", ".vbe", ".js", ".jse", ".wsf", ".wsh", ".hta", ".lnk", ".reg",
        ".jar", ".apk", ".aab", ".ipa", ".app", ".dmg", ".pkg", ".deb", ".rpm", ".sh", ".bash",
        ".zsh", ".command", ".run", ".bin", ".iso", ".img", ".vhd", ".zip", ".rar", ".7z", ".tar",
        ".gz", ".tgz", ".bz2", ".xz", ".cab", ".docm", ".xlsm", ".pptm", ".svg", ".swf"
    ];

    // Signatures de fichiers exécutables ou d'archives, refusées quel que soit le nom.
    private static readonly byte[][] DangerousSignatures =
    [
        "MZ"u8.ToArray(),                          // Windows (exe, dll)
        [0x7F, (byte)'E', (byte)'L', (byte)'F'],   // Linux
        [0xFE, 0xED, 0xFA, 0xCE], [0xFE, 0xED, 0xFA, 0xCF],
        [0xCE, 0xFA, 0xED, 0xFE], [0xCF, 0xFA, 0xED, 0xFE],
        [0xCA, 0xFE, 0xBA, 0xBE],                  // macOS, Java
        "PK\u0003\u0004"u8.ToArray(),              // zip, apk, jar, docx
        "Rar!"u8.ToArray(),
        [(byte)'7', (byte)'z', 0xBC, 0xAF],
        [0x1F, 0x8B],                              // gzip
        "#!"u8.ToArray()                           // script shell
    ];

    // Actions de PDF capables de lancer un programme ou d'exécuter du code.
    private static readonly string[] DangerousPdfTokens = ["/JavaScript", "/Launch", "/EmbeddedFile"];

    public static string AcceptedFormatsLabel => "PDF, PNG, JPG, WebP, page HTML, texte (.txt, .md)";

    public static bool IsBlockedExtension(string extension) => BlockedExtensions.Contains(extension);

    public static RevisionFileCheck Inspect(string? fileName, ReadOnlySpan<byte> content)
    {
        var safeName = SanitizeFileName(fileName);
        var extension = Path.GetExtension(safeName).ToLowerInvariant();

        if (BlockedExtensions.Contains(extension))
        {
            return RevisionFileCheck.Refused(
                $"Les fichiers {extension} sont interdits pour la sécurité de la classe.");
        }

        if (!AllowedByExtension.TryGetValue(extension, out var format))
        {
            return RevisionFileCheck.Refused($"Format non accepté. Formats possibles : {AcceptedFormatsLabel}.");
        }

        if (content.IsEmpty) return RevisionFileCheck.Refused("Le fichier est vide.");
        if (content.Length > format.MaxBytes)
        {
            return RevisionFileCheck.Refused(
                $"Fichier trop lourd : {format.MaxBytes / (1024 * 1024)} Mo maximum pour ce format.");
        }

        foreach (var signature in DangerousSignatures)
        {
            if (content.StartsWith(signature))
            {
                return RevisionFileCheck.Refused(
                    "Ce fichier contient un programme ou une archive : il est refusé pour la sécurité de la classe.");
            }
        }

        var matches = format.Type switch
        {
            "pdf" => content.StartsWith("%PDF-"u8),
            "image" => MatchesImage(format, content),
            _ => IsPlainUtf8Text(content)
        };
        if (!matches)
        {
            return RevisionFileCheck.Refused(
                $"Le contenu ne correspond pas à un fichier {format.Label} : il a peut-être été renommé.");
        }

        if (format.Type == "pdf" && ContainsPdfAction(content))
        {
            return RevisionFileCheck.Refused(
                "Ce PDF contient du code ou un fichier joint : il est refusé pour la sécurité de la classe.");
        }

        return new RevisionFileCheck(true, null, safeName, format.Type, format.ContentType);
    }

    /// <summary>Garde un nom lisible, sans chemin ni caractère spécial, extension comprise.</summary>
    public static string SanitizeFileName(string? fileName)
    {
        var name = Path.GetFileName((fileName ?? string.Empty).Replace('\\', '/'));
        var builder = new StringBuilder(name.Length);
        foreach (var character in name)
        {
            if (char.IsControl(character) || "/:*?\"<>|".Contains(character)) continue;
            builder.Append(character);
        }

        var cleaned = string.Join(' ', builder.ToString().Split(' ', StringSplitOptions.RemoveEmptyEntries)).Trim('.', ' ');
        if (cleaned.Length == 0) return "fichier";
        if (cleaned.Length <= MaxFileNameLength) return cleaned;

        var extension = Path.GetExtension(cleaned);
        if (extension.Length > 10) extension = string.Empty;
        return cleaned[..(MaxFileNameLength - extension.Length)] + extension;
    }

    private static bool MatchesImage(AllowedFormat format, ReadOnlySpan<byte> content) => format.Label switch
    {
        "PNG" => content.StartsWith(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
        "JPG" => content.StartsWith(new byte[] { 0xFF, 0xD8, 0xFF }),
        "WebP" => content.Length > 12 && content.StartsWith("RIFF"u8) && content[8..12].SequenceEqual("WEBP"u8),
        _ => false
    };

    private static bool IsPlainUtf8Text(ReadOnlySpan<byte> content)
    {
        if (content.IndexOf((byte)0) >= 0) return false;

        try
        {
            _ = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true).GetCharCount(content);
            return true;
        }
        catch (DecoderFallbackException)
        {
            return false;
        }
    }

    private static bool ContainsPdfAction(ReadOnlySpan<byte> content)
    {
        foreach (var token in DangerousPdfTokens)
        {
            if (content.IndexOf(Encoding.ASCII.GetBytes(token)) >= 0) return true;
        }

        return false;
    }

    private sealed record AllowedFormat(string Type, string Label, string ContentType, long MaxBytes)
    {
        public static readonly AllowedFormat Pdf = new("pdf", "PDF", "application/pdf", 10 * 1024 * 1024);
        public static readonly AllowedFormat Png = new("image", "PNG", "image/png", 8 * 1024 * 1024);
        public static readonly AllowedFormat Jpeg = new("image", "JPG", "image/jpeg", 8 * 1024 * 1024);
        public static readonly AllowedFormat Webp = new("image", "WebP", "image/webp", 8 * 1024 * 1024);
        public static readonly AllowedFormat Html = new("html", "HTML", "text/html; charset=utf-8", 2 * 1024 * 1024);
        public static readonly AllowedFormat Text = new("text", "texte", "text/plain; charset=utf-8", 1024 * 1024);
    }
}

public sealed record RevisionFileCheck(
    bool IsAccepted,
    string? Error,
    string? FileName,
    string? FileType,
    string? ContentType)
{
    public static RevisionFileCheck Refused(string error) => new(false, error, null, null, null);
}
