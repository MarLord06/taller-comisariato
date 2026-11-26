using System.Diagnostics;
using Npgsql;
using Polly;
using Polly.Retry;

namespace Comisariato.Api.Infrastructure;

public static class PollyPolicies
{
    public static AsyncRetryPolicy CrearReintentoDeadlock(ILogger logger) =>
        Policy.Handle<PostgresException>(error => error.SqlState == PostgresErrorCodes.DeadlockDetected)
            .WaitAndRetryAsync(
                retryCount: 1,
                sleepDurationProvider: _ => TimeSpan.FromMilliseconds(1000),
                onRetry: (error, delay, intento, _) =>
                    logger.LogError(error,
                        "Deadlock PostgreSQL 40P01. Reintento {Intento} en {DemoraMs} ms. Solicitud {TraceId}",
                        intento, delay.TotalMilliseconds, Activity.Current?.Id));
}
