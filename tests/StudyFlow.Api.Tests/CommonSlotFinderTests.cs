using StudyFlow.Application.Groups;

namespace StudyFlow.Api.Tests;

public sealed class CommonSlotFinderTests
{
    private static readonly DateOnly Monday = new(2026, 10, 12);
    private static readonly TimeOnly Morning = new(7, 0);

    [Fact]
    public void A_school_day_offers_breaks_on_site_then_the_evening_remotely()
    {
        var day = new SlotDay(Monday, [Range(9, 0, 12, 0), Range(13, 30, 16, 0)], IsDayOff: false);

        var slots = CommonSlotFinder.Find([day], [Member(), Member()], 60, Monday, Morning);

        Assert.Equal(
            [(Range(12, 0, 13, 30), SlotMode.OnSite), (Range(16, 0, 17, 30), SlotMode.OnSite), (Range(18, 15, 21, 0), SlotMode.Remote)],
            slots.Select(x => (x.Range, x.Mode)).ToArray());
    }

    [Fact]
    public void A_weekday_without_class_is_a_company_day()
    {
        var day = new SlotDay(Monday, [], IsDayOff: false);

        var slots = CommonSlotFinder.Find([day], [Member(companyEnd: new TimeOnly(17, 0)), Member(companyEnd: new TimeOnly(18, 0))], 60, Monday, Morning);

        var slot = Assert.Single(slots);
        Assert.Equal(Range(18, 45, 21, 0), slot.Range);
        Assert.Equal(SlotMode.Remote, slot.Mode);
    }

    [Fact]
    public void The_weekend_is_used_only_if_everyone_accepts_it()
    {
        var saturday = new SlotDay(Monday.AddDays(5), [], IsDayOff: false);

        Assert.Empty(CommonSlotFinder.Find([saturday], [Member(weekend: true), Member(weekend: false)], 60, Monday, Morning));
        Assert.Equal(Range(10, 0, 21, 0), Assert.Single(CommonSlotFinder.Find([saturday], [Member(weekend: true), Member(weekend: true)], 60, Monday, Morning)).Range);
    }

    [Fact]
    public void Personal_events_block_time_and_when_nothing_fits_one_missing_person_is_suggested()
    {
        var day = new SlotDay(Monday, [], IsDayOff: false);
        var busyAllEvening = new Dictionary<DateOnly, IReadOnlyList<TimeRange>> { [Monday] = [Range(18, 0, 22, 0)] };
        var lina = Member(busy: busyAllEvening);

        var slots = CommonSlotFinder.Find([day], [Member(), Member(), lina], 60, Monday, Morning);

        var slot = Assert.Single(slots);
        Assert.Equal([lina.UserId], slot.MissingUserIds);
    }

    [Fact]
    public void Nothing_is_proposed_in_the_next_half_hour()
    {
        var day = new SlotDay(Monday, [], IsDayOff: false);

        var slots = CommonSlotFinder.Find([day], [Member(), Member()], 60, Monday, new TimeOnly(19, 0));

        Assert.Equal(Range(19, 30, 21, 0), Assert.Single(slots).Range);
    }

    private static TimeRange Range(int startHour, int startMinute, int endHour, int endMinute) =>
        new(new TimeOnly(startHour, startMinute), new TimeOnly(endHour, endMinute));

    private static SlotMember Member(
        TimeOnly? companyEnd = null,
        bool weekend = false,
        IReadOnlyDictionary<DateOnly, IReadOnlyList<TimeRange>>? busy = null) =>
        new(Guid.NewGuid(), companyEnd ?? new TimeOnly(17, 30), new TimeOnly(21, 0), weekend, busy ?? new Dictionary<DateOnly, IReadOnlyList<TimeRange>>());
}
