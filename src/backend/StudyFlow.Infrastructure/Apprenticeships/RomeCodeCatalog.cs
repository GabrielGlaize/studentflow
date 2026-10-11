using System.Globalization;
using System.Text;

namespace StudyFlow.Infrastructure.Apprenticeships;

/// <summary>
/// Codes ROME (fiches métiers de France Travail) des domaines d'alternance les plus courants.
/// La bonne alternance cherche par code ROME, pas par mots-clés : « développeur » devient M1805.
/// </summary>
public static class RomeCodeCatalog
{
    private const int MaxCodes = 10;

    // Débuts de mots sans accents → codes ROME. Un mot-clé peut toucher plusieurs domaines.
    private static readonly (string[] Stems, string[] Codes)[] Domains =
    [
        (["develop", "programm", "logiciel", "fullstack", "frontend", "backend", "web", "appli", "codeur", "data"], ["M1805"]),
        (["informati", "numerique"], ["M1805", "M1810", "M1801", "I1401"]),
        (["reseau", "systeme", "cyber", "devops", "cloud", "sysadmin"], ["M1801", "M1810", "M1802"]),
        (["support", "helpdesk", "technicien informatique"], ["I1401", "M1810"]),
        (["commerc", "business", "vente", "negoci"], ["D1402", "D1403", "D1407"]),
        (["vendeu", "pret-a-porter", "boutique"], ["D1214", "D1106", "D1501"]),
        (["magasin", "distribution", "rayon", "caiss", "libre service"], ["D1507", "D1503", "D1505", "D1301"]),
        (["compta", "comptab"], ["M1203", "M1206"]),
        (["gestion", "controle de gestion", "gestionnaire"], ["M1204", "M1203"]),
        (["financ", "audit"], ["M1202", "M1201"]),
        (["banque", "bancaire"], ["C1206", "C1201"]),
        (["assuranc"], ["C1102", "C1101"]),
        (["ressources humaines", "rh", "recrut", "paie"], ["M1501", "M1502", "M1503"]),
        (["marketing"], ["M1705", "M1703"]),
        (["communication", "evenementiel"], ["E1103", "E1101"]),
        (["digital", "reseaux sociaux", "community", "seo"], ["E1101", "M1705"]),
        (["graphis", "design", "ux", "ui", "infograph", "motion"], ["E1205", "E1104"]),
        (["assistant", "administratif", "secretari", "office manager"], ["M1602", "M1604", "M1607", "M1605"]),
        (["accueil", "hote", "hotesse"], ["M1601"]),
        (["logisti", "supply", "entrepot", "magasinier", "preparat", "cariste"], ["N1301", "N1303", "N1103", "N1101"]),
        (["transport"], ["N1201", "N1301"]),
        (["achat", "acheteu"], ["M1101"]),
        (["immobili", "agent immo"], ["C1501", "C1502", "C1504"]),
        (["hotel", "reception"], ["G1703"]),
        (["restaura", "serveu", "cuisin", "commis", "barman"], ["G1602", "G1603", "G1803"]),
        (["boulang"], ["D1102"]),
        (["patiss"], ["D1104"]),
        (["bouch", "charcut"], ["D1101"]),
        (["coiff"], ["D1202"]),
        (["esthet", "beaute", "onglerie"], ["D1208"]),
        (["btp", "batiment", "chantier", "conducteur de travaux", "genie civil"], ["F1201", "F1106", "F1104"]),
        (["macon"], ["F1703"]),
        (["electric"], ["F1602", "I1309"]),
        (["plomb", "chauffag", "cvc", "climatis"], ["F1603"]),
        (["menuis", "charpent"], ["H2206", "F1607"]),
        (["mecani", "automobile", "garage", "auto"], ["I1604"]),
        (["carross"], ["I1606"]),
        (["maintenance"], ["I1304", "I1309"]),
        (["soud", "chaudronn"], ["H2913"]),
        (["industri", "production", "usine"], ["H2502", "H1206"]),
        (["qualite"], ["H1502"]),
        (["electroni", "electrotech", "automatis"], ["H1209", "I1309"]),
        (["aide soignant", "soignant", "sante"], ["J1501"]),
        (["pharmac"], ["J1307"]),
        (["petite enfance", "creche", "puericult", "cap aepe"], ["K1303", "J1304"]),
        (["social", "educat"], ["K1207", "K1201"]),
        (["juridi", "droit", "notari", "avocat"], ["K1902", "K1903"]),
        (["tourisme", "voyage"], ["G1303", "G1102"]),
        (["agricol", "agricult", "elevage"], ["A1416"]),
        (["paysag", "espaces verts", "jardin"], ["A1203"]),
        (["horticul", "maraich"], ["A1414"]),
        (["architect"], ["F1101"]),
        (["sport"], ["G1204"]),
        (["agent de securite", "surveillance", "securite privee"], ["K2503"]),
        (["nettoyage", "proprete"], ["K2204"]),
        (["audiovisuel", "video", "montage"], ["L1509"]),
        (["photo"], ["E1201"]),
        (["journalis"], ["E1106"])
    ];

    /// <summary>Codes ROME des domaines reconnus dans les mots-clés ; vide si aucun ne l'est.</summary>
    public static IReadOnlyCollection<string> Match(string keywords)
    {
        var words = Words(keywords);
        if (words.Length == 0) return [];

        var text = $" {string.Join(' ', words)} ";
        var codes = new List<string>();
        foreach (var (stems, domainCodes) in Domains)
        {
            if (!stems.Any(stem => Matches(text, words, stem))) continue;
            foreach (var code in domainCodes.Where(code => !codes.Contains(code))) codes.Add(code);
        }

        return codes.Take(MaxCodes).ToArray();
    }

    /// <summary>Mots utiles pour filtrer des offres : sans accents, sans « alternance » ni mots courts.</summary>
    public static string[] Words(string text) =>
        RemoveDiacritics(text.ToLowerInvariant())
            .Split([' ', ',', ';', '/', '-', '\'', '’', '(', ')', '.'], StringSplitOptions.RemoveEmptyEntries)
            .Where(word => word.Length >= 2 && !IgnoredWords.Contains(word))
            .ToArray();

    public static string RemoveDiacritics(string value)
    {
        var builder = new StringBuilder(value.Length);
        foreach (var character in value.Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark) builder.Append(character);
        }

        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    private static readonly HashSet<string> IgnoredWords =
        ["alternance", "alternant", "alternante", "apprentissage", "apprenti", "apprentie", "contrat", "stage", "en", "de", "du", "des", "la", "le", "les", "et", "ou", "un", "une", "h/f", "hf", "f/h"];

    // Un radical court (« rh », « ui », « ux », « auto ») doit être un mot entier : « ui » ne doit pas
    // reconnaître « cuisine ». Les radicaux plus longs reconnaissent un début de mot.
    private static bool Matches(string text, string[] words, string stem) =>
        stem.Contains(' ')
            ? text.Contains($" {stem}", StringComparison.Ordinal)
            : stem.Length <= 4
                ? words.Contains(stem)
                : words.Any(word => word.StartsWith(stem, StringComparison.Ordinal));
}
