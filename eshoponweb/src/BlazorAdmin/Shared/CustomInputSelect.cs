using Microsoft.AspNetCore.Components.Forms;

namespace BlazorAdmin.Shared;

/// <summary>
/// Provides integer-compatible InputSelect until native framework support is available.
/// See: https://www.pragimtech.com/blog/blazor/inputselect-does-not-support-system.int32/
/// </summary>
/// <typeparam name="TValue">The bound value type.</typeparam>
public class CustomInputSelect<TValue> : InputSelect<TValue>
{
    protected override bool TryParseValueFromString(
        string value,
        out TValue result,
        out string validationErrorMessage)
    {
        if (typeof(TValue) == typeof(int))
        {
            if (int.TryParse(value, out var resultInt))
            {
                result = (TValue)(object)resultInt;
                validationErrorMessage = null;
                return true;
            }

            result = default;
            validationErrorMessage =
                $"The selected value {value} is not a valid number.";
            return false;
        }

        return base.TryParseValueFromString(value, out result, out validationErrorMessage);
    }
}
