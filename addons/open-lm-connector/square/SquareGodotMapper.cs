using Godot;
using GodotDictionary = Godot.Collections.Dictionary;

namespace LaunchMonitors.Square;

public static class SquareGodotMapper
{
    public static GodotDictionary ToBallData(SquareShotMetrics metrics)
    {
        var values = SquareShotDataMapper.ToOsgBallData(metrics);
        var data = new GodotDictionary();

        foreach (var item in values)
        {
            data[item.Key] = ToVariant(item.Value);
        }

        return data;
    }

    private static Variant ToVariant(object value)
    {
        return value switch
        {
            float floatValue => Variant.From(floatValue),
            int intValue => Variant.From(intValue),
            string stringValue => Variant.From(stringValue),
            _ => Variant.From(value.ToString() ?? string.Empty)
        };
    }
}
