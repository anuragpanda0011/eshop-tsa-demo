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
    private readonly object _lock = new object();
    private bool _disposed;

    public void ShowToast(string message, ToastLevel level)
    {
        OnShow?.Invoke(message, level);
        StartCountdown();
    }

    private void StartCountdown()
    {
        lock (_lock)
        {
            EnsureCountdown();

            if (_countdown.Enabled)
            {
                _countdown.Stop();
            }

            _countdown.Start();
        }
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
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;

        if (disposing)
        {
            lock (_lock)
            {
                _countdown?.Stop();
                _countdown?.Dispose();
                _countdown = null;
            }
        }

        _disposed = true;
    }
}
