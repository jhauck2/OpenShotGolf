using Godot;

/// <summary>
/// Controls debug output verbosity for the OpenFairway physics addon.
/// Set via C#: PhysicsLogger.LogLevel = PhysicsLogger.Level.Info
/// Set via GDScript: PhysicsLogger.set_level(2)  # 0=Off,1=Error,2=Info,3=Verbose
/// </summary>
[GlobalClass]
public partial class PhysicsLogger : RefCounted
{
    public enum Level { Off = 0, Error = 1, Info = 2, Verbose = 3 }

    private static Level _level = Level.Error;

    // C# API (type-safe)
    public static Level LogLevel { get => _level; set => _level = value; }

    // GDScript API (static methods accessible via class name in Godot 4.3+)
    public static void SetLevel(int level) => _level = (Level)level;
    public static int GetLevel() => (int)_level;
    /// <summary>GDScript-facing alias for <see cref="Info"/>; GDScript calls PhysicsLogger.INFO("msg").</summary>
    public static void INFO(string message) => Info(message);

    // Used internally by physics classes
    internal static void Info(string message)    { if (_level >= Level.Info)    GD.Print(message); }
    internal static void Verbose(string message) { if (_level >= Level.Verbose) GD.Print(message); }
    internal static void Error(string message)   { if (_level >= Level.Error)   GD.PrintErr(message); }
    internal static void PushError(string message) { if (_level >= Level.Error) GD.PushError(message); }
}
