using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace StudyFlow.Infrastructure.Persistence;

public sealed class StudyFlowDbContextFactory : IDesignTimeDbContextFactory<StudyFlowDbContext>
{
    public StudyFlowDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("STUDYFLOW_POSTGRES")
            ?? "Host=localhost;Port=5433;Database=studyflow;Username=studyflow;Password=studyflow";

        var options = new DbContextOptionsBuilder<StudyFlowDbContext>()
            .UseNpgsql(connectionString)
            .Options;

        return new StudyFlowDbContext(options);
    }
}
