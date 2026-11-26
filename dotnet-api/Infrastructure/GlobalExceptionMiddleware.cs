using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebUtilities;
using Npgsql;

namespace Comisariato.Api.Infrastructure;

public sealed class GlobalExceptionMiddleware(
    RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception error) when (!context.Response.HasStarted && !context.RequestAborted.IsCancellationRequested)
        {
            var sqlState = (error as PostgresException)?.SqlState;
            var status = (error, sqlState) switch
            {
                (RecursoNoEncontradoException, _) => StatusCodes.Status404NotFound,
                (_, "P0400") => StatusCodes.Status400BadRequest,
                (_, "P0404") => StatusCodes.Status404NotFound,
                (_, "P0409") => StatusCodes.Status409Conflict,
                (_, "P0422") => StatusCodes.Status422UnprocessableEntity,
                _ => StatusCodes.Status500InternalServerError
            };
            var traceId = Activity.Current?.Id ?? context.TraceIdentifier;

            logger.LogError(error,
                "HTTP {Status} en {Method} {Path}. SQLSTATE {SqlState}. Solicitud {TraceId}",
                status, context.Request.Method, context.Request.Path, sqlState, traceId);

            var detail = status == StatusCodes.Status500InternalServerError
                ? "No se pudo completar la operación."
                : (error as PostgresException)?.MessageText ?? error.Message;
            var problem = new ProblemDetails
            {
                Type = "about:blank",
                Title = ReasonPhrases.GetReasonPhrase(status),
                Status = status,
                Detail = detail,
                Instance = context.Request.Path
            };
            problem.Extensions["traceId"] = traceId;

            context.Response.Clear();
            context.Response.StatusCode = status;
            await context.Response.WriteAsJsonAsync(problem, options: null,
                contentType: "application/problem+json", cancellationToken: context.RequestAborted);
        }
    }
}

internal sealed class RecursoNoEncontradoException(string message) : Exception(message);
