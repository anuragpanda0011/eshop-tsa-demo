using Microsoft.AspNetCore.Components.Forms;

namespace BlazorAdmin.Shared;

/// <summary>
/// Extends <see cref="InputSelect{TValue}"/> to support <see cref="int"/>
/// binding, which was not natively supported prior to .NET 5.
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
                $"The selected value '{value}' is not a valid number.";
            return false;
        }

        return base.TryParseValueFromString(value, out result, out validationErrorMessage);
    }
}
