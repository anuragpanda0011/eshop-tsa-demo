using System;
using System.Timers;

namespace BlazorAdmin.Services;

public enum ToastLevel
{
    Info,
    Success,
    Warning,
    Error
}

public class ToastService : IDisposable
{
    public event Action<string, ToastLevel> OnShow;
    public event Action OnHide;

    private Timer _countdown;

    public void ShowToast(string message, ToastLevel level)
    {
        OnShow?.Invoke(message, level);
        StartCountdown();
    }

    private void StartCountdown()
    {
        EnsureCountdown();

        if (_countdown.Enabled)
        {
            _countdown.Stop();
        }

        _countdown.Start();
    }

    private void EnsureCountdown()
    {
        if (_countdown == null)
        {
            _countdown = new Timer(3000)
            {
                AutoReset = false
            };
            _countdown.Elapsed += HideToast;
        }
    }

    private void HideToast(object source, ElapsedEventArgs args)
    {
        OnHide?.Invoke();
    }

    public void Dispose()
    {
        _countdown?.Dispose();
    }
}
