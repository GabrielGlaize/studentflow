using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace StudyFlow.Infrastructure.Persistence;

public sealed class StudyFlowDbContextFactory : IDesignTimeDbContextFactory<StudyFlowDbContext>
{
    public StudyFlowDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("STUDYFLOW_POSTGRES")
            ?? throw new InvalidOperationException("La variable STUDYFLOW_POSTGRES est requise pour les outils EF.");

        var options = new DbContextOptionsBuilder<StudyFlowDbContext>()
            .UseNpgsql(connectionString)
            .Options;

        return new StudyFlowDbContext(options);
    }
}
