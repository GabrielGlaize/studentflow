using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class ExamTests(ApiFixture fixture)
{
    private static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    [Fact]
    public async Task The_revision_sheet_opens_to_the_class_two_weeks_before_the_exams()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);

        var later = await CreateSessionAsync(scenario.Delegate, subject.Id, Today.AddDays(20));
        Assert.False(later.IsOpen);
        Assert.Equal(later.StartsOn.AddDays(-14), later.OpensOn);

        var studentView = await fixture.Api.As(scenario.Student)
            .GetFromJsonAsync<ExamSessionResponse[]>("/api/v1/exams", ApiScenario.Json);
        Assert.Empty(studentView!);

        var delegateView = await fixture.Api.As(scenario.Delegate)
            .GetFromJsonAsync<ExamSessionResponse[]>("/api/v1/exams", ApiScenario.Json);
        Assert.Single(delegateView!);

        var sheet = await fixture.Api.As(scenario.Student).GetAsync($"/api/v1/exams/subjects/{later.Subjects.Single().Id}");
        Assert.Equal(HttpStatusCode.NotFound, sheet.StatusCode);
    }

    [Fact]
    public async Task Students_fill_the_sheet_and_track_their_own_progress()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var session = await CreateSessionAsync(scenario.Delegate, subject.Id, Today.AddDays(10));
        var examSubjectId = session.Subjects.Single().Id;
        var student = fixture.Api.As(scenario.Student);

        var item = await (await student.PostAsJsonAsync($"/api/v1/exams/subjects/{examSubjectId}/items",
            new RevisionItemRequest("Chapitre 3 : les intégrales"))).ReadSuccessAsync<RevisionItemResponse>();
        Assert.True(item.IsMine);
        Assert.Equal("Liam M.", item.AuthorName);

        var check = await student.PutAsJsonAsync($"/api/v1/exams/items/{item.Id}/check", new RevisionCheckRequest(true));
        Assert.Equal(HttpStatusCode.NoContent, check.StatusCode);

        var sheet = await student.GetFromJsonAsync<ExamSubjectSheetResponse>($"/api/v1/exams/subjects/{examSubjectId}", ApiScenario.Json);
        var listed = Assert.Single(sheet!.Items);
        Assert.True(listed.CheckedByMe);
        Assert.Equal(1, listed.CheckCount);

        // La case est personnelle : le délégué voit le point, pas coché pour lui.
        var delegateSheet = await fixture.Api.As(scenario.Delegate)
            .GetFromJsonAsync<ExamSubjectSheetResponse>($"/api/v1/exams/subjects/{examSubjectId}", ApiScenario.Json);
        Assert.False(delegateSheet!.Items.Single().CheckedByMe);

        var sessions = await student.GetFromJsonAsync<ExamSessionResponse[]>("/api/v1/exams", ApiScenario.Json);
        var summary = sessions!.Single().Subjects.Single();
        Assert.Equal(1, summary.ItemCount);
        Assert.Equal(1, summary.CheckedByMeCount);
        Assert.Equal(1, summary.ContributorCount);
    }

    [Fact]
    public async Task Only_the_author_or_a_delegate_can_remove_a_contribution()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var session = await CreateSessionAsync(scenario.Delegate, subject.Id, Today.AddDays(5));
        var examSubjectId = session.Subjects.Single().Id;

        var otherEmail = ApiScenario.NewEmail();
        var other = await fixture.Api.RegisterAsync(otherEmail);
        await fixture.Api.JoinAndApproveAsync(other, scenario.Delegate, scenario.ClassCode);
        other = await fixture.Api.LoginAsync(otherEmail);

        var item = await (await fixture.Api.As(scenario.Student).PostAsJsonAsync(
            $"/api/v1/exams/subjects/{examSubjectId}/items",
            new RevisionItemRequest("Savoir refaire le TD 4"))).ReadSuccessAsync<RevisionItemResponse>();

        var byOther = await fixture.Api.As(other).DeleteAsync($"/api/v1/exams/items/{item.Id}");
        Assert.Equal(HttpStatusCode.Forbidden, byOther.StatusCode);

        var byDelegate = await fixture.Api.As(scenario.Delegate).DeleteAsync($"/api/v1/exams/items/{item.Id}");
        Assert.Equal(HttpStatusCode.NoContent, byDelegate.StatusCode);
    }

    [Fact]
    public async Task Only_delegates_plan_the_exams()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);

        var response = await fixture.Api.As(scenario.Student).PostAsJsonAsync("/api/v1/exams",
            new ExamSessionRequest("Partiels S1", Today.AddDays(5), Today.AddDays(7), [new ExamSubjectRequest(subject.Id)]));

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData("http://exemple.fr/cours", "https://")]
    [InlineData("https://exemple.fr/outil.exe", "interdit")]
    [InlineData("javascript:alert(1)", "https://")]
    [InlineData("https://moi:secret@exemple.fr", "mot de passe")]
    public async Task Unsafe_links_are_refused(string url, string expectedMessage)
    {
        var (client, examSubjectId) = await OpenSheetAsync();

        var response = await client.PostAsJsonAsync($"/api/v1/exams/subjects/{examSubjectId}/links", new RevisionLinkRequest(url));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(expectedMessage, await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task A_claude_artifact_link_is_shared_with_the_class()
    {
        var (client, examSubjectId) = await OpenSheetAsync();

        var resource = await (await client.PostAsJsonAsync($"/api/v1/exams/subjects/{examSubjectId}/links",
            new RevisionLinkRequest("https://claude.ai/public/artifacts/1234", "Quiz sur les graphes")))
            .ReadSuccessAsync<RevisionResourceResponse>();

        Assert.Equal("link", resource.Kind);
        Assert.Equal("Quiz sur les graphes", resource.Title);
        Assert.Equal("https://claude.ai/public/artifacts/1234", resource.Url);
    }

    [Fact]
    public async Task A_renamed_executable_is_refused()
    {
        var (client, examSubjectId) = await OpenSheetAsync();

        var asPdf = await UploadAsync(client, examSubjectId, "cours.pdf", [(byte)'M', (byte)'Z', 0x90, 0x00, 0x03]);
        Assert.Equal(HttpStatusCode.BadRequest, asPdf.StatusCode);
        Assert.Contains("programme", await asPdf.Content.ReadAsStringAsync());

        var asExe = await UploadAsync(client, examSubjectId, "setup.exe", Encoding.UTF8.GetBytes("hello"));
        Assert.Equal(HttpStatusCode.BadRequest, asExe.StatusCode);
        Assert.Contains(".exe", await asExe.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task A_pdf_and_an_html_page_are_stored_and_downloaded_safely()
    {
        var (client, examSubjectId) = await OpenSheetAsync();
        var pdf = Encoding.ASCII.GetBytes("%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\n%%EOF");
        var html = Encoding.UTF8.GetBytes("<!doctype html><title>Quiz</title><script>alert('révise !')</script>");

        var pdfResource = await (await UploadAsync(client, examSubjectId, "Annales 2025.pdf", pdf))
            .ReadSuccessAsync<RevisionResourceResponse>();
        Assert.Equal("pdf", pdfResource.FileType);
        Assert.Equal("Annales 2025", pdfResource.Title);

        var htmlResource = await (await UploadAsync(client, examSubjectId, "quiz.html", html))
            .ReadSuccessAsync<RevisionResourceResponse>();
        Assert.Equal("html", htmlResource.FileType);

        var download = await client.GetAsync($"/api/v1/exams/resources/{htmlResource.Id}/file");
        Assert.Equal(HttpStatusCode.OK, download.StatusCode);
        Assert.Equal(html, await download.Content.ReadAsByteArrayAsync());
        Assert.Equal("nosniff", download.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.StartsWith("sandbox", download.Headers.GetValues("Content-Security-Policy").Single());
        Assert.Equal("attachment", download.Content.Headers.ContentDisposition?.DispositionType);
    }

    [Fact]
    public async Task A_pdf_that_launches_a_program_is_refused()
    {
        var (client, examSubjectId) = await OpenSheetAsync();
        var pdf = Encoding.ASCII.GetBytes("%PDF-1.4\n1 0 obj << /OpenAction << /S /Launch /F (calc.exe) >> >> endobj");

        var response = await UploadAsync(client, examSubjectId, "cours.pdf", pdf);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    private async Task<(HttpClient Client, Guid ExamSubjectId)> OpenSheetAsync()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var session = await CreateSessionAsync(scenario.Delegate, subject.Id, Today.AddDays(7));
        return (fixture.Api.As(scenario.Student), session.Subjects.Single().Id);
    }

    private async Task<ExamSessionResponse> CreateSessionAsync(AuthResponse delegateSession, Guid subjectId, DateOnly startsOn)
    {
        var response = await fixture.Api.As(delegateSession).PostAsJsonAsync("/api/v1/exams", new ExamSessionRequest(
            "Partiels S1",
            startsOn,
            startsOn.AddDays(4),
            [new ExamSubjectRequest(subjectId, startsOn, new TimeOnly(9, 0), "QCM, 1 h 30")]));
        return await response.ReadSuccessAsync<ExamSessionResponse>();
    }

    private static Task<HttpResponseMessage> UploadAsync(HttpClient client, Guid examSubjectId, string fileName, byte[] content)
    {
        var form = new MultipartFormDataContent();
        var file = new ByteArrayContent(content);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        form.Add(file, "file", fileName);
        return client.PostAsync($"/api/v1/exams/subjects/{examSubjectId}/files", form);
    }
}
