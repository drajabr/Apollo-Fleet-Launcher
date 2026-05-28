namespace ApolloFleet.Core;

public sealed class SettingsValidationException : Exception
{
    public SettingsValidationException(string message) : base(message) { }
}
