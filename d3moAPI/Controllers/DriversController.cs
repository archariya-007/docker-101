using d3moAPI.Data;
using d3moAPI.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace d3moAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class DriversController : ControllerBase
    {
        
        private readonly ILogger<DriversController> _logger;
        private readonly ApiDbContext _context;

        public DriversController(ILogger<DriversController> logger, ApiDbContext context)
        {
            _logger = logger;
            _context = context;
        }

        [HttpGet(Name = "GetDrivers")]
        public async Task<IActionResult> Get()
        {
            // var driver = new Driver
            // {
            //     Id = 1,
            //     Name = "Hulk Smash",
            //     DriverNumber = 100
            // };
            // _context.Add(driver);
            // await _context.SaveChangesAsync();

            var drivers = await _context.Drivers.ToListAsync();
            return Ok(drivers);
        
        }
    }
}