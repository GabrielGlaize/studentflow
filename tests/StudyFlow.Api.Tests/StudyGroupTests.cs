using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class StudyGroupTests(ApiFixture fixture)
{
    private static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    [Fact]
    public async Task A_group_is_private_to_its_members_and_its_content_is_encrypted()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var outsider = await AddClassmateAsync(scenario);
        var organizer = fixture.Api.As(scenario.Delegate);

        var group = await (await organizer.PostAsJsonAsync("/api/v1/groups", new StudyGroupRequest(
                "Projet BDD", "Modéliser la base de la médiathèque", InviteeIds: [scenario.Student.User.Id])))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        Assert.True(group.CanManage);
        Assert.Equal("organizer", group.Summary.MyRole);
        Assert.Equal(2, group.Members.Count);

        // L'invité voit l'invitation, pas encore le contenu.
        var student = fixture.Api.As(scenario.Student);
        var invitation = Assert.Single((await student.GetFromJsonAsync<StudyGroupSummaryResponse[]>("/api/v1/groups", ApiScenario.Json))!);
        Assert.Equal("invited", invitation.Status);
        Assert.Equal("Gabriel D.", invitation.InvitedByName);
        Assert.Equal(HttpStatusCode.NotFound, (await student.GetAsync($"/api/v1/groups/{group.Summary.Id}/messages")).StatusCode);

        await (await student.PostAsync($"/api/v1/groups/{group.Summary.Id}/accept", null)).ReadSuccessAsync<StudyGroupDetailResponse>();
        var message = await (await student.PostAsJsonAsync($"/api/v1/groups/{group.Summary.Id}/messages",
            new StudyGroupMessageRequest("Je m'occupe du MCD ce soir"))).ReadSuccessAsync<StudyGroupMessageResponse>();
        Assert.True(message.IsMine);

        var thread = (await organizer.GetFromJsonAsync<StudyGroupMessageResponse[]>($"/api/v1/groups/{group.Summary.Id}/messages", ApiScenario.Json))!;
        Assert.Contains(thread, x => x.AuthorId is null && x.Text.Contains("a rejoint le groupe"));
        Assert.Contains(thread, x => x.Text == "Je m'occupe du MCD ce soir" && !x.IsMine);
        var summary = Assert.Single((await organizer.GetFromJsonAsync<StudyGroupSummaryResponse[]>("/api/v1/groups", ApiScenario.Json))!);
        Assert.True(summary.UnreadCount >= 1);

        // Un camarade de classe hors du groupe ne voit rien, pas même son existence.
        var other = fixture.Api.As(outsider);
        Assert.Empty((await other.GetFromJsonAsync<StudyGroupSummaryResponse[]>("/api/v1/groups", ApiScenario.Json))!);
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/v1/groups/{group.Summary.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsJsonAsync($"/api/v1/groups/{group.Summary.Id}/messages",
            new StudyGroupMessageRequest("coucou"))).StatusCode);

        await using var scope = fixture.Api.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
        var stored = await dbContext.StudyGroupMessages.Where(x => x.StudyGroupId == group.Summary.Id).ToListAsync();
        Assert.All(stored, x => Assert.DoesNotContain("MCD", x.EncryptedText));
        var storedGroup = await dbContext.StudyGroups.SingleAsync(x => x.Id == group.Summary.Id);
        Assert.DoesNotContain("médiathèque", storedGroup.EncryptedDescription);
    }

    [Fact]
    public async Task Tasks_are_assigned_to_members_and_land_in_their_agenda()
    {
        var (scenario, groupId) = await CreateGroupOfTwoAsync();
        var organizer = fixture.Api.As(scenario.Delegate);
        var student = fixture.Api.As(scenario.Student);

        var task = await (await organizer.PostAsJsonAsync($"/api/v1/groups/{groupId}/tasks", new StudyGroupTaskRequest(
                "Rédiger l'introduction", DueOn: Today.AddDays(3), AssigneeIds: [scenario.Student.User.Id])))
            .ReadSuccessAsync<StudyGroupTaskResponse>();
        Assert.Equal("todo", task.Status);
        Assert.False(task.IsMine);
        Assert.Equal(["Liam M."], task.AssigneeNames);

        var agenda = await student.GetFromJsonAsync<StudyGroupAgendaResponse>("/api/v1/groups/agenda", ApiScenario.Json);
        var mine = Assert.Single(agenda!.Tasks);
        Assert.Equal("Rédiger l'introduction", mine.Title);

        var done = await (await student.PutAsJsonAsync($"/api/v1/groups/tasks/{task.Id}/status", new StudyGroupTaskStatusRequest("done")))
            .ReadSuccessAsync<StudyGroupTaskResponse>();
        Assert.Equal("done", done.Status);
        Assert.NotNull(done.CompletedAt);
        Assert.Empty((await student.GetFromJsonAsync<StudyGroupAgendaResponse>("/api/v1/groups/agenda", ApiScenario.Json))!.Tasks);

        var detail = await organizer.GetFromJsonAsync<StudyGroupDetailResponse>($"/api/v1/groups/{groupId}", ApiScenario.Json);
        Assert.Equal(1, detail!.Summary.TaskCount);
        Assert.Equal(1, detail.Summary.DoneTaskCount);
        Assert.Equal(1, detail.Members.Single(x => !x.IsMe).DoneTaskCount);

        // Une tâche ne s'affecte qu'aux membres du groupe.
        var stranger = await organizer.PostAsJsonAsync($"/api/v1/groups/{groupId}/tasks",
            new StudyGroupTaskRequest("Diapos", AssigneeIds: [Guid.NewGuid()]));
        Assert.Equal(HttpStatusCode.BadRequest, stranger.StatusCode);
    }

    [Fact]
    public async Task A_student_is_in_only_one_group_per_homework_and_the_class_sees_who_is_alone()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var third = await AddClassmateAsync(scenario);
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var course = await fixture.Api.CreateCourseAsync(scenario.Delegate, subject.Id);
        var homework = await (await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/homework", new HomeworkRequest(
                "Dossier réseau", null, DateTimeOffset.UtcNow.AddDays(10), course.Id, IsGroupWork: true)))
            .ReadSuccessAsync<HomeworkResponse>();
        Assert.True(homework.IsGroupWork);

        var first = await (await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/groups", new StudyGroupRequest(
                "Équipe 1", HomeworkId: homework.Id, InviteeIds: [scenario.Student.User.Id])))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        Assert.Equal(homework.Deadline, first.Summary.DueAt);
        Assert.Equal("Dossier réseau", first.Summary.HomeworkTitle);
        Assert.Equal(subject.Id, first.Summary.SubjectId);

        var second = await (await fixture.Api.As(third).PostAsJsonAsync("/api/v1/groups", new StudyGroupRequest(
                "Équipe 2", HomeworkId: homework.Id, InviteeIds: [scenario.Student.User.Id])))
            .ReadSuccessAsync<StudyGroupDetailResponse>();

        // L'élève invité deux fois rejoint le premier : l'autre invitation tombe.
        var student = fixture.Api.As(scenario.Student);
        await (await student.PostAsync($"/api/v1/groups/{first.Summary.Id}/accept", null)).ReadSuccessAsync<StudyGroupDetailResponse>();
        var groups = (await student.GetFromJsonAsync<StudyGroupSummaryResponse[]>("/api/v1/groups", ApiScenario.Json))!;
        Assert.Equal(first.Summary.Id, Assert.Single(groups).Id);

        // Il ne peut plus être invité ailleurs pour ce devoir.
        var again = await fixture.Api.As(third).PostAsJsonAsync($"/api/v1/groups/{second.Summary.Id}/invitations",
            new StudyGroupInviteRequest([scenario.Student.User.Id]));
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);

        var overview = await student.GetFromJsonAsync<StudyGroupHomeworkOverviewResponse>(
            $"/api/v1/groups/homework/{homework.Id}/overview", ApiScenario.Json);
        Assert.Equal(2, overview!.Groups.Count);
        Assert.True(overview.Groups.Single(x => x.Id == first.Summary.Id).IsMine);
        Assert.Empty(overview.StudentsWithoutGroup);

        var classmates = (await fixture.Api.As(third).GetFromJsonAsync<StudyGroupClassmateResponse[]>(
            $"/api/v1/groups/classmates?homeworkId={homework.Id}", ApiScenario.Json))!;
        Assert.Equal("Équipe 1", classmates.Single(x => x.UserId == scenario.Student.User.Id).GroupName);
    }

    [Fact]
    public async Task The_organizer_hands_over_when_leaving_and_the_last_member_takes_the_group_away()
    {
        var (scenario, groupId) = await CreateGroupOfTwoAsync();
        var organizer = fixture.Api.As(scenario.Delegate);
        var student = fixture.Api.As(scenario.Student);

        var forbidden = await student.DeleteAsync($"/api/v1/groups/{groupId}/members/{scenario.Delegate.User.Id}");
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);

        var role = await (await student.PutAsJsonAsync($"/api/v1/groups/{groupId}/me/role", new StudyGroupRoleLabelRequest("Diapos")))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        Assert.Equal("Diapos", role.Members.Single(x => x.IsMe).RoleLabel);

        Assert.Equal(HttpStatusCode.NoContent, (await organizer.PostAsync($"/api/v1/groups/{groupId}/leave", null)).StatusCode);
        var detail = await student.GetFromJsonAsync<StudyGroupDetailResponse>($"/api/v1/groups/{groupId}", ApiScenario.Json);
        Assert.True(detail!.CanManage);
        Assert.Single(detail.Members);

        Assert.Equal(HttpStatusCode.NoContent, (await student.PostAsync($"/api/v1/groups/{groupId}/leave", null)).StatusCode);
        await using var scope = fixture.Api.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
        Assert.False(await dbContext.StudyGroups.AnyAsync(x => x.Id == groupId));
    }

    [Fact]
    public async Task Common_slots_respect_class_days_and_meetings_need_everyone()
    {
        var (scenario, groupId) = await CreateGroupOfTwoAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var schoolDay = NextWeekday(Today.AddDays(2));
        await fixture.Api.CreateCourseAsync(scenario.Delegate, subject.Id, schoolDay, new TimeOnly(9, 0));
        await fixture.Api.CreateCourseAsync(scenario.Delegate, subject.Id, schoolDay, new TimeOnly(14, 0));

        var student = fixture.Api.As(scenario.Student);
        var availability = await (await student.PutAsJsonAsync("/api/v1/groups/availability",
                new UserAvailabilityRequest(new TimeOnly(18, 0), new TimeOnly(21, 0), WeekendAvailable: false)))
            .ReadSuccessAsync<UserAvailabilityResponse>();
        Assert.False(availability.IsDefault);

        var slots = await student.GetFromJsonAsync<StudyGroupSlotsResponse>($"/api/v1/groups/{groupId}/slots?durationMinutes=60", ApiScenario.Json);
        Assert.Contains(slots!.Slots, x => x.Day == schoolDay && x.Mode == "onsite" && x.StartsAt == new TimeOnly(10, 0));
        Assert.DoesNotContain(slots.Slots, x => x.Day.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday);
        // Jour en entreprise : rien avant la fin du travail (18 h) et le trajet.
        Assert.All(slots.Slots.Where(x => x.Day != schoolDay), x => Assert.True(x.StartsAt >= new TimeOnly(18, 45)));
        Assert.Contains("Gabriel D.", slots.MembersWithDefaultAvailability);

        var local = schoolDay.ToDateTime(new TimeOnly(10, 0));
        var startsAt = new DateTimeOffset(local, TimeZoneInfo.FindSystemTimeZoneById("Europe/Paris").GetUtcOffset(local));
        var meeting = await (await student.PostAsJsonAsync($"/api/v1/groups/{groupId}/meetings",
                new StudyGroupMeetingRequest(startsAt, startsAt.AddHours(1), "onsite", "CDI")))
            .ReadSuccessAsync<StudyGroupMeetingResponse>();
        Assert.Equal("proposed", meeting.Status);
        Assert.True(meeting.MyAnswer);

        var confirmed = await (await fixture.Api.As(scenario.Delegate).PutAsJsonAsync($"/api/v1/groups/meetings/{meeting.Id}/vote",
            new StudyGroupMeetingVoteRequest(true))).ReadSuccessAsync<StudyGroupMeetingResponse>();
        Assert.Equal("confirmed", confirmed.Status);

        var agenda = await student.GetFromJsonAsync<StudyGroupAgendaResponse>("/api/v1/groups/agenda", ApiScenario.Json);
        Assert.Equal("CDI", Assert.Single(agenda!.Meetings).Place);

        // La réunion confirmée occupe désormais ce créneau pour le groupe.
        var after = await student.GetFromJsonAsync<StudyGroupSlotsResponse>($"/api/v1/groups/{groupId}/slots?durationMinutes=60", ApiScenario.Json);
        Assert.DoesNotContain(after!.Slots, x => x.Day == schoolDay && x.StartsAt == new TimeOnly(10, 0));
    }

    [Fact]
    public async Task Group_files_are_encrypted_and_only_members_download_them()
    {
        var (scenario, groupId) = await CreateGroupOfTwoAsync();
        using var form = new MultipartFormDataContent();
        var file = new ByteArrayContent("Plan du rapport : intro, analyse, conclusion"u8.ToArray());
        form.Add(file, "file", "plan.txt");

        var resource = await (await fixture.Api.As(scenario.Student).PostAsync($"/api/v1/groups/{groupId}/files", form))
            .ReadSuccessAsync<StudyGroupResourceResponse>();
        Assert.Equal("plan", resource.Title);

        var download = await fixture.Api.As(scenario.Delegate).GetAsync($"/api/v1/groups/resources/{resource.Id}/file");
        Assert.Equal("Plan du rapport : intro, analyse, conclusion", await download.Content.ReadAsStringAsync());

        var outsider = await AddClassmateAsync(scenario);
        Assert.Equal(HttpStatusCode.NotFound, (await fixture.Api.As(outsider).GetAsync($"/api/v1/groups/resources/{resource.Id}/file")).StatusCode);

        await using var scope = fixture.Api.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
        var stored = await dbContext.StudyGroupResourceFiles.SingleAsync(x => x.StudyGroupResourceId == resource.Id);
        Assert.DoesNotContain("rapport", System.Text.Encoding.UTF8.GetString(stored.EncryptedContent));
    }

    private async Task<(ClassScenario Scenario, Guid GroupId)> CreateGroupOfTwoAsync()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var group = await (await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/groups",
                new StudyGroupRequest("Projet", InviteeIds: [scenario.Student.User.Id])))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        await (await fixture.Api.As(scenario.Student).PostAsync($"/api/v1/groups/{group.Summary.Id}/accept", null))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        return (scenario, group.Summary.Id);
    }

    private async Task<AuthResponse> AddClassmateAsync(ClassScenario scenario)
    {
        var email = ApiScenario.NewEmail();
        var student = await fixture.Api.RegisterAsync(email);
        await fixture.Api.JoinAndApproveAsync(student, scenario.Delegate, scenario.ClassCode);
        return await fixture.Api.LoginAsync(email);
    }

    private static DateOnly NextWeekday(DateOnly day)
    {
        while (day.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday) day = day.AddDays(1);
        return day;
    }
}
