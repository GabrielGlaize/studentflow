using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using StudyFlow.Api.Contracts;

namespace StudyFlow.Api.Tests.Infrastructure;

/// <summary>Raccourcis pour construire des situations réalistes (classe, délégué, élèves).</summary>
public static class ApiScenario
{
    public const string Password = "Motdepasse123!";

    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static string NewEmail(string prefix = "eleve") => $"{prefix}-{Guid.NewGuid():N}@tests.studyflow";

    public static string NewClassName() => $"Classe {Guid.NewGuid():N}"[..30];

    public static HttpClient Anonymous(this WebApplicationFactory<Program> factory) => factory.CreateClient();

    public static HttpClient As(this WebApplicationFactory<Program> factory, AuthResponse session)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.Tokens.AccessToken);
        return client;
    }

    public static async Task<AuthResponse> RegisterAsync(this WebApplicationFactory<Program> factory, string? email = null)
    {
        var response = await factory.Anonymous().PostAsJsonAsync("/api/v1/auth/register", new RegisterRequest(
            email ?? NewEmail(), Password, "Liam", "Martin"));
        return await response.ReadSuccessAsync<AuthResponse>();
    }

    public static async Task<AuthResponse> LoginAsync(this WebApplicationFactory<Program> factory, string email)
    {
        var response = await factory.Anonymous().PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, Password));
        return await response.ReadSuccessAsync<AuthResponse>();
    }

    /// <summary>Crée une classe (son créateur devient délégué) et un élève approuvé.</summary>
    public static async Task<ClassScenario> CreateClassWithStudentAsync(this WebApplicationFactory<Program> factory)
    {
        var delegateEmail = NewEmail("delegue");
        var created = await factory.Anonymous().PostAsJsonAsync("/api/v1/auth/register-and-create-class",
            new RegisterAndCreateClassRequest(delegateEmail, Password, "Gabriel", "Delegue", NewClassName(), "2026-2027"));
        var delegateSession = await created.ReadSuccessAsync<AuthResponse>();

        var studentEmail = NewEmail();
        var student = await factory.RegisterAsync(studentEmail);
        await factory.JoinAndApproveAsync(student, delegateSession, delegateSession.ClassCode!);

        // L'approbation change le security stamp : l'ancien access token de l'élève n'est plus valide.
        var studentSession = await factory.LoginAsync(studentEmail);
        return new ClassScenario(delegateSession, delegateEmail, studentSession, studentEmail, delegateSession.ClassCode!);
    }

    public static async Task JoinAndApproveAsync(
        this WebApplicationFactory<Program> factory,
        AuthResponse student,
        AuthResponse delegateSession,
        string classCode)
    {
        var join = await factory.As(student).PostAsJsonAsync("/api/v1/classes/join", new JoinClassRequest(classCode));
        var membership = await join.ReadSuccessAsync<MembershipRequestResponse>();

        var approve = await factory.As(delegateSession)
            .PostAsync($"/api/v1/delegate/membership-requests/{membership.Id}/approve", null);
        Assert.Equal(HttpStatusCode.NoContent, approve.StatusCode);
    }

    public static async Task<SubjectResponse> CreateSubjectAsync(this WebApplicationFactory<Program> factory, AuthResponse delegateSession)
    {
        var response = await factory.As(delegateSession)
            .PostAsJsonAsync("/api/v1/class-resources/subjects", new SubjectRequest($"Maths {Guid.NewGuid():N}"[..20]));
        return await response.ReadSuccessAsync<SubjectResponse>();
    }

    public static async Task<CourseResponse> CreateCourseAsync(
        this WebApplicationFactory<Program> factory,
        AuthResponse session,
        Guid subjectId,
        DateOnly? day = null,
        TimeOnly? startsAt = null)
    {
        var start = startsAt ?? new TimeOnly(8, 0);
        var response = await factory.As(session).PostAsJsonAsync("/api/v1/courses", new CourseRequest(
            subjectId, null, day ?? DateOnly.FromDateTime(DateTime.UtcNow.AddDays(2)), start, start.AddHours(1), "B204"));
        return await response.ReadSuccessAsync<CourseResponse>();
    }

    public static async Task<T> ReadSuccessAsync<T>(this HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, $"HTTP {(int)response.StatusCode} : {body}");
        return JsonSerializer.Deserialize<T>(body, Json)!;
    }
}

public sealed record ClassScenario(
    AuthResponse Delegate,
    string DelegateEmail,
    AuthResponse Student,
    string StudentEmail,
    string ClassCode);
