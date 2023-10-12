using Microsoft.EntityFrameworkCore;
using d3moAPI.Models;

namespace d3moAPI.Data;

public class ApiDbContext : DbContext
{
    public ApiDbContext(DbContextOptions<ApiDbContext> options) : base(options) { }
    public DbSet<Driver> Drivers { get; set; }
}

