using System.Diagnostics;
using System.Text.Json.Serialization;
using Comisariato.Api.Infrastructure;
using Comisariato.Api.Repositories;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding.Metadata;
using Microsoft.AspNetCore.WebUtilities;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);
if (string.IsNullOrWhiteSpace(builder.Configuration["urls"]))
{
    builder.WebHost.UseUrls("http://localhost:5080");
}

builder.Services
    .AddControllers(options =>
        options.ModelMetadataDetailsProviders.Add(new SystemTextJsonValidationMetadataProvider()))
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.NumberHandling = JsonNumberHandling.Strict;
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = false;
        options.AllowInputFormatterExceptionMessages = false;
    });

builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    var defaultResponseFactory = options.InvalidModelStateResponseFactory;
    options.InvalidModelStateResponseFactory = context =>
    {
        var logger = context.HttpContext.RequestServices.GetRequiredService<ILogger<Program>>();
        var invalidFields = context.ModelState
            .Where(entry => entry.Value?.Errors.Count > 0)
            .Select(entry => entry.Key);
        var error = context.ModelState.Values
            .SelectMany(entry => entry.Errors)
            .Select(modelError => modelError.Exception)
            .FirstOrDefault(exception => exception is not null);
        var traceId = Activity.Current?.Id ?? context.HttpContext.TraceIdentifier;

        logger.LogError(error, "Validación HTTP 400 en {Method} {Path}. Campos: {Fields}. Solicitud {TraceId}",
            context.HttpContext.Request.Method, context.HttpContext.Request.Path,
            string.Join(", ", invalidFields), traceId);

        var response = defaultResponseFactory(context);
        if (response is ObjectResult { Value: ValidationProblemDetails problem })
        {
            problem.Type = "about:blank";
            problem.Title = ReasonPhrases.GetReasonPhrase(StatusCodes.Status400BadRequest);
            problem.Detail = "Revise los campos de la solicitud.";
            problem.Instance = context.HttpContext.Request.Path;
        }

        return response;
    };
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
    options.SwaggerDoc("v1", new()
    {
        Title = "Comisariato — API .NET",
        Version = "v1",
        Description = "Ventas e inventario del Comisariato en PostgreSQL."
    }));

var connectionString = builder.Configuration.GetConnectionString("Comisariato")
    ?? throw new InvalidOperationException("Falta configurar ConnectionStrings:Comisariato.");
builder.Services.AddSingleton(_ => NpgsqlDataSource.Create(connectionString));
builder.Services.AddSingleton(services =>
    PollyPolicies.CrearReintentoDeadlock(services.GetRequiredService<ILogger<VentaService>>()));
builder.Services.AddScoped<IVentaService, VentaService>();
builder.Services.AddScoped<IProductoService, ProductoService>();
builder.Services.AddScoped<IVentaRepository, VentaRepository>();
builder.Services.AddScoped<IProductoRepository, ProductoRepository>();
builder.Services.AddHealthChecks().AddCheck<PostgresHealthCheck>(
    "postgresql", timeout: TimeSpan.FromSeconds(5));

var app = builder.Build();
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseSwagger();
app.UseSwaggerUI(options => options.SwaggerEndpoint("/swagger/v1/swagger.json", "Comisariato v1"));
app.MapControllers();
app.MapHealthChecks("/health");
app.Run();
