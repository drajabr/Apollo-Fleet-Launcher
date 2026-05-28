using System.Globalization;
using System.IO;
using System.Xml.Linq;
using System.Windows.Markup;

namespace ApolloFleet.App;

internal static class Strings
{
    private static readonly object Gate = new();
    private static readonly Dictionary<string, Dictionary<string, string>> Catalog =
        new(StringComparer.OrdinalIgnoreCase);

    private static readonly string I18nDirectory =
        Path.Combine(AppContext.BaseDirectory, "i18n");

    public static string Get(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return key;

        try
        {
            var culture = CultureInfo.CurrentUICulture;
            foreach (var locale in GetLocaleCandidates(culture))
            {
                var dict = GetLocaleDictionary(locale);
                if (dict.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
                    return value;
            }
        }
        catch
        {
            // Ignore and fall back to key.
        }

        return key;
    }

    private static IEnumerable<string> GetLocaleCandidates(CultureInfo culture)
    {
        if (!string.IsNullOrWhiteSpace(culture.Name))
            yield return culture.Name;

        if (!string.IsNullOrWhiteSpace(culture.TwoLetterISOLanguageName))
            yield return culture.TwoLetterISOLanguageName;

        yield return "en";
    }

    private static Dictionary<string, string> GetLocaleDictionary(string locale)
    {
        lock (Gate)
        {
            if (Catalog.TryGetValue(locale, out var cached))
                return cached;

            var loaded = LoadLocaleDictionary(locale);
            Catalog[locale] = loaded;
            return loaded;
        }
    }

    private static Dictionary<string, string> LoadLocaleDictionary(string locale)
    {
        var fileName = string.Equals(locale, "en", StringComparison.OrdinalIgnoreCase)
            ? "Resources.resx"
            : $"Resources.{locale}.resx";

        var path = Path.Combine(I18nDirectory, fileName);
        if (!File.Exists(path))
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        try
        {
            var doc = XDocument.Load(path);
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var data in doc.Root?.Elements("data") ?? Enumerable.Empty<XElement>())
            {
                var name = data.Attribute("name")?.Value;
                if (string.IsNullOrWhiteSpace(name))
                    continue;

                var value = data.Element("value")?.Value ?? string.Empty;
                map[name] = value;
            }

            return map;
        }
        catch
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
    }
}

[MarkupExtensionReturnType(typeof(string))]
public sealed class LocStringExtension : MarkupExtension
{
    public LocStringExtension() { }
    public LocStringExtension(string key) => Key = key;
    public string Key { get; set; } = "";
    public override object ProvideValue(IServiceProvider serviceProvider) => Strings.Get(Key);
}
