using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class ValidationTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_too_long_announcement_is_a_400_not_a_500()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();

        var response = await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/class-announcements",
            new ClassAnnouncementRequest(new string('a', 2001)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task A_too_long_homework_title_is_a_400_not_a_500()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();

        var response = await fixture.Api.As(scenario.Student).PostAsJsonAsync("/api/v1/homework",
            new HomeworkRequest(new string('a', 161), null, DateTimeOffset.UtcNow.AddDays(3)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("file:///etc/passwd")]
    public async Task Links_must_be_web_addresses(string link)
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var client = fixture.Api.As(scenario.Student);

        var message = await client.PostAsJsonAsync("/api/v1/apprenticeship-messages",
            new ApprenticeshipMessageRequest("Regardez cette offre", link));
        Assert.Equal(HttpStatusCode.BadRequest, message.StatusCode);

        var favorite = await client.PostAsJsonAsync("/api/v1/apprenticeships/favorite-offers",
            new FavoriteOfferRequest("adzuna", "42", "Développeur", null, null, link));
        Assert.Equal(HttpStatusCode.BadRequest, favorite.StatusCode);
    }

    [Fact]
    public async Task Deadlines_sent_with_a_time_zone_offset_are_accepted()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var course = await fixture.Api.CreateCourseAsync(scenario.Student, subject.Id);
        var deadline = new DateTimeOffset(2026, 11, 20, 18, 0, 0, TimeSpan.FromHours(1));

        var response = await fixture.Api.As(scenario.Student).PostAsJsonAsync("/api/v1/homework",
            new HomeworkRequest("Rapport de stage", null, deadline, course.Id));

        var homework = await response.ReadSuccessAsync<HomeworkResponse>();
        Assert.Equal(deadline.UtcDateTime, homework.Deadline.UtcDateTime);
    }
}
