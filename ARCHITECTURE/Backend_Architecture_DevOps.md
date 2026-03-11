# PICKLEBALL APP — BACKEND ARCHITECTURE & DEVOPS
## Tài Liệu Kiến Trúc Backend & Hạ Tầng Triển Khai

**Phiên bản:** 1.0
**Ngày:** Tháng 3, 2026
**Công nghệ chính:** .NET 8 | PostgreSQL | Redis | SignalR | Docker

---

## MỤC LỤC

1. [Kiến trúc Backend](#1-kiến-trúc-backend)
2. [Chi tiết từng tầng (Layer)](#2-chi-tiết-từng-tầng)
3. [Cross-Cutting Concerns](#3-cross-cutting-concerns)
4. [Realtime — SignalR](#4-realtime--signalr)
5. [Background Jobs & Queue](#5-background-jobs--queue)
6. [Caching Strategy](#6-caching-strategy)
7. [File Storage](#7-file-storage)
8. [DevOps & CI/CD](#8-devops--cicd)
9. [Hạ tầng triển khai (Infrastructure)](#9-hạ-tầng-triển-khai)
10. [Monitoring & Observability](#10-monitoring--observability)
11. [Bảo mật (Security)](#11-bảo-mật)
12. [Quy ước lập trình (Coding Conventions)](#12-quy-ước-lập-trình)

---

## 1. Kiến Trúc Backend

### 1.1. Tổng quan — Clean Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENTS                               │
│   React Web App  |  React Native App  |  Admin Panel     │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS (REST + SignalR WebSocket)
┌────────────────────────▼────────────────────────────────┐
│              PickleballApp.API                            │
│   ┌──────────────┐ ┌──────────┐ ┌────────────────────┐  │
│   │ Controllers   │ │ Hubs     │ │ Middleware          │  │
│   │ (REST API)    │ │(SignalR) │ │ Auth | Error | Log  │  │
│   └──────┬───────┘ └────┬─────┘ └────────────────────┘  │
└──────────┼──────────────┼───────────────────────────────┘
           │              │
┌──────────▼──────────────▼───────────────────────────────┐
│              PickleballApp.Application                    │
│   ┌──────────────┐ ┌──────────┐ ┌────────────────────┐  │
│   │ Services      │ │ DTOs     │ │ Validators          │  │
│   │ (Use Cases)   │ │          │ │ (FluentValidation)  │  │
│   └──────┬───────┘ └──────────┘ └────────────────────┘  │
│          │                                               │
│   ┌──────▼───────┐                                       │
│   │ Interfaces    │  ← Dependency Inversion              │
│   └──────┬───────┘                                       │
└──────────┼──────────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────────┐
│              PickleballApp.Domain                         │
│   ┌──────────────┐ ┌──────────┐ ┌────────────────────┐  │
│   │ Entities      │ │ Enums    │ │ Value Objects       │  │
│   │ (POCO)        │ │          │ │ Score, Rating...    │  │
│   └──────────────┘ └──────────┘ └────────────────────┘  │
│   ┌──────────────┐ ┌──────────────────────────────────┐  │
│   │ Domain Events │ │ Domain Exceptions                │  │
│   └──────────────┘ └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
           ▲
┌──────────┼──────────────────────────────────────────────┐
│              PickleballApp.Infrastructure                 │
│   ┌──────────────┐ ┌──────────┐ ┌────────────────────┐  │
│   │ EF Core       │ │ Redis    │ │ Cloudinary          │  │
│   │ DbContext     │ │ Cache    │ │ File Storage        │  │
│   │ Repositories  │ │ Service  │ │ Service (Miễn phí)  │  │
│   └──────────────┘ └──────────┘ └────────────────────┘  │
│   ┌──────────────┐ ┌──────────┐ ┌────────────────────┐  │
│   │ FCM Push      │ │ Email    │ │ Background Jobs     │  │
│   │ Notification  │ │ Service  │ │ (Hosted Services)   │  │
│   └──────────────┘ └──────────┘ └────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 1.2. Nguyên tắc kiến trúc

| Nguyên tắc | Áp dụng |
|------------|---------|
| **Dependency Inversion** | Tầng trong (Domain, Application) không phụ thuộc tầng ngoài (Infrastructure) |
| **Single Responsibility** | Mỗi Service xử lý 1 aggregate/module |
| **Interface Segregation** | Interface nhỏ, chuyên biệt (ITournamentRepository, IMatchRepository) |
| **Repository Pattern** | Trừu tượng hóa data access, dễ test và thay đổi ORM |
| **CQRS nhẹ** | Tách Read DTOs và Write Commands (không cần Event Sourcing) |

### 1.3. Dependency Flow

```
API → Application → Domain
 ↓                    ↑
Infrastructure ───────┘ (implements interfaces from Application)
```

- **API** tham chiếu: Application, Infrastructure (cho DI registration)
- **Application** tham chiếu: Domain
- **Infrastructure** tham chiếu: Application (implement interfaces), Domain (sử dụng entities)
- **Domain** không tham chiếu project nào → hoàn toàn độc lập

---

## 2. Chi Tiết Từng Tầng

### 2.1. Domain Layer — `PickleballApp.Domain`

```
PickleballApp.Domain/
├── Entities/
│   ├── User.cs
│   ├── Tournament.cs
│   ├── Participant.cs
│   ├── Team.cs
│   ├── Group.cs
│   ├── GroupMember.cs
│   ├── Match.cs
│   ├── CommunityGame.cs
│   ├── GameParticipant.cs
│   ├── ChatRoom.cs
│   ├── ChatMember.cs
│   ├── Message.cs
│   ├── Notification.cs
│   ├── Follow.cs
│   └── RefreshToken.cs
├── Enums/
│   ├── TournamentType.cs          // Singles, Doubles
│   ├── TournamentStatus.cs        // Draft, Open, Ready, InProgress, Completed, Cancelled
│   ├── ScoringFormat.cs           // BestOf1, BestOf3
│   ├── ParticipantStatus.cs       // Confirmed, InvitedPending, RequestPending, Rejected
│   ├── MatchStatus.cs             // Scheduled, InProgress, Completed, Walkover
│   ├── GameStatus.cs              // Open, Full, InProgress, Completed, Cancelled
│   ├── GameParticipantStatus.cs   // Confirmed, Waitlist, InvitedPending, Cancelled
│   ├── ChatRoomType.cs            // Direct, Group
│   ├── MessageType.cs             // Text, Image, System
│   └── NotificationType.cs        // TournamentInvite, RequestApproved, MatchResult, ...
├── ValueObjects/
│   ├── SetScore.cs                // { Player1Score: int, Player2Score: int }
│   ├── MatchScore.cs              // List<SetScore>, WinnerId
│   └── Location.cs                // { Address: string, Lat: decimal, Lng: decimal }
├── Events/
│   ├── TournamentCreatedEvent.cs
│   ├── MatchCompletedEvent.cs
│   ├── ParticipantJoinedEvent.cs
│   └── ScoreUpdatedEvent.cs
├── Exceptions/
│   ├── DomainException.cs
│   ├── TournamentFullException.cs
│   ├── InvalidScoreException.cs
│   └── InvalidStatusTransitionException.cs
└── Common/
    ├── BaseEntity.cs              // Id, CreatedAt, UpdatedAt
    └── IAuditableEntity.cs
```

**Ví dụ Entity:**

```csharp
// Entities/Tournament.cs
public class Tournament : BaseEntity
{
    public int CreatorId { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
    public TournamentType Type { get; set; }
    public int NumGroups { get; set; }
    public ScoringFormat ScoringFormat { get; set; } = ScoringFormat.BestOf3;
    public TournamentStatus Status { get; set; } = TournamentStatus.Draft;
    public DateOnly? Date { get; set; }
    public string? Location { get; set; }
    public string? BannerUrl { get; set; }

    // Navigation properties
    public User Creator { get; set; } = null!;
    public ICollection<Participant> Participants { get; set; } = [];
    public ICollection<Team> Teams { get; set; } = [];
    public ICollection<Group> Groups { get; set; } = [];
    public ICollection<Match> Matches { get; set; } = [];

    // Domain logic
    public int MaxParticipants => Type == TournamentType.Singles
        ? NumGroups * 4
        : NumGroups * 4 * 2; // Doubles: 4 teams x 2 players

    public bool IsFull(int currentCount) => currentCount >= MaxParticipants;

    public void ValidateStatusTransition(TournamentStatus newStatus)
    {
        var allowed = Status switch
        {
            TournamentStatus.Draft => new[] { TournamentStatus.Open, TournamentStatus.Cancelled },
            TournamentStatus.Open => new[] { TournamentStatus.Ready, TournamentStatus.Cancelled },
            TournamentStatus.Ready => new[] { TournamentStatus.InProgress, TournamentStatus.Cancelled },
            TournamentStatus.InProgress => new[] { TournamentStatus.Completed },
            _ => Array.Empty<TournamentStatus>()
        };

        if (!allowed.Contains(newStatus))
            throw new InvalidStatusTransitionException(Status, newStatus);
    }
}
```

**Ví dụ Value Object:**

```csharp
// ValueObjects/SetScore.cs
public record SetScore(int Player1Score, int Player2Score)
{
    public bool IsValid()
    {
        if (Player1Score < 0 || Player2Score < 0) return false;

        var maxScore = Math.Max(Player1Score, Player2Score);
        var minScore = Math.Min(Player1Score, Player2Score);

        // Thắng set khi đạt 11 điểm, cách biệt ít nhất 2
        if (maxScore < 11) return false;
        if (maxScore == 11 && minScore > 9) return false;
        if (maxScore > 11 && maxScore - minScore != 2) return false;

        return true;
    }

    public int? GetWinnerId(int player1Id, int player2Id)
        => Player1Score > Player2Score ? player1Id : player2Id;
}
```

### 2.2. Application Layer — `PickleballApp.Application`

```
PickleballApp.Application/
├── Common/
│   ├── Interfaces/
│   │   ├── IApplicationDbContext.cs
│   │   ├── ICurrentUserService.cs
│   │   ├── ICacheService.cs
│   │   ├── IFileStorageService.cs
│   │   ├── IPushNotificationService.cs
│   │   └── IEmailService.cs
│   ├── Models/
│   │   ├── PagedResult<T>.cs
│   │   ├── Result<T>.cs
│   │   └── PaginationParams.cs
│   ├── Mappings/
│   │   └── MappingProfile.cs        // AutoMapper profiles
│   └── Exceptions/
│       ├── NotFoundException.cs
│       ├── ForbiddenException.cs
│       └── ValidationException.cs
├── Auth/
│   ├── DTOs/
│   │   ├── RegisterRequest.cs
│   │   ├── LoginRequest.cs
│   │   ├── AuthResponse.cs
│   │   └── RefreshTokenRequest.cs
│   ├── Validators/
│   │   ├── RegisterRequestValidator.cs
│   │   └── LoginRequestValidator.cs
│   └── Services/
│       ├── IAuthService.cs
│       └── AuthService.cs
├── Users/
│   ├── DTOs/
│   │   ├── UserProfileDto.cs
│   │   ├── UpdateProfileRequest.cs
│   │   └── UserSummaryDto.cs
│   ├── Validators/
│   │   └── UpdateProfileValidator.cs
│   └── Services/
│       ├── IUserService.cs
│       └── UserService.cs
├── Tournaments/
│   ├── DTOs/
│   │   ├── CreateTournamentRequest.cs
│   │   ├── UpdateTournamentRequest.cs
│   │   ├── TournamentDto.cs
│   │   ├── TournamentListDto.cs
│   │   ├── TournamentFilterParams.cs
│   │   ├── InvitePlayerRequest.cs
│   │   ├── GroupAssignmentRequest.cs
│   │   └── TeamAssignmentRequest.cs
│   ├── Validators/
│   │   ├── CreateTournamentValidator.cs
│   │   └── UpdateTournamentValidator.cs
│   └── Services/
│       ├── ITournamentService.cs
│       ├── TournamentService.cs
│       ├── IParticipantService.cs
│       ├── ParticipantService.cs
│       ├── ITeamService.cs
│       ├── TeamService.cs
│       ├── IGroupService.cs
│       └── GroupService.cs
├── Matches/
│   ├── DTOs/
│   │   ├── MatchDto.cs
│   │   ├── SubmitScoreRequest.cs
│   │   ├── StandingsDto.cs
│   │   └── TournamentResultsDto.cs
│   ├── Validators/
│   │   └── SubmitScoreValidator.cs
│   └── Services/
│       ├── IMatchService.cs
│       ├── MatchService.cs
│       ├── IStandingsService.cs
│       ├── StandingsService.cs
│       └── RoundRobinGenerator.cs     // Tạo lịch thi đấu Round Robin
├── Community/
│   ├── DTOs/
│   │   ├── CreateGameRequest.cs
│   │   ├── GameDto.cs
│   │   └── GameFilterParams.cs
│   └── Services/
│       ├── ICommunityGameService.cs
│       └── CommunityGameService.cs
├── Chat/
│   ├── DTOs/
│   │   ├── ChatRoomDto.cs
│   │   ├── MessageDto.cs
│   │   └── SendMessageRequest.cs
│   └── Services/
│       ├── IChatService.cs
│       └── ChatService.cs
└── Notifications/
    ├── DTOs/
    │   └── NotificationDto.cs
    └── Services/
        ├── INotificationService.cs
        └── NotificationService.cs
```

**Ví dụ Service:**

```csharp
// Tournaments/Services/TournamentService.cs
public class TournamentService : ITournamentService
{
    private readonly IApplicationDbContext _db;
    private readonly ICurrentUserService _currentUser;
    private readonly INotificationService _notification;
    private readonly ICacheService _cache;

    public async Task<TournamentDto> CreateAsync(CreateTournamentRequest request)
    {
        var tournament = new Tournament
        {
            CreatorId = _currentUser.UserId,
            Name = request.Name,
            Description = request.Description,
            Type = request.Type,
            NumGroups = request.NumGroups,
            ScoringFormat = request.ScoringFormat,
            Date = request.Date,
            Location = request.Location,
            Status = TournamentStatus.Draft
        };

        _db.Tournaments.Add(tournament);
        await _db.SaveChangesAsync();

        await _cache.RemoveByPrefixAsync("tournaments:list");
        return tournament.ToDto();
    }

    public async Task ChangeStatusAsync(int id, TournamentStatus newStatus)
    {
        var tournament = await _db.Tournaments
            .Include(t => t.Participants)
            .Include(t => t.Groups)
            .FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new NotFoundException(nameof(Tournament), id);

        if (tournament.CreatorId != _currentUser.UserId)
            throw new ForbiddenException();

        tournament.ValidateStatusTransition(newStatus);

        // Validate điều kiện chuyển trạng thái
        if (newStatus == TournamentStatus.Ready)
        {
            var confirmedCount = tournament.Participants.Count(p => p.Status == ParticipantStatus.Confirmed);
            if (confirmedCount < tournament.NumGroups * 4)
                throw new DomainException("Chưa đủ người tham gia để chuyển sang trạng thái sẵn sàng");
            if (!tournament.Groups.Any())
                throw new DomainException("Chưa xếp bảng");
        }

        tournament.Status = newStatus;
        await _db.SaveChangesAsync();

        // Thông báo cho tất cả người tham gia
        await _notification.NotifyTournamentStatusChanged(tournament);
    }
}
```

**Ví dụ Round Robin Generator:**

```csharp
// Matches/Services/RoundRobinGenerator.cs
public static class RoundRobinGenerator
{
    /// <summary>
    /// Tạo lịch Round Robin cho 1 bảng 4 đơn vị.
    /// Pattern cố định:
    ///   Vòng 1: A vs B, C vs D
    ///   Vòng 2: A vs C, B vs D
    ///   Vòng 3: A vs D, B vs C
    /// </summary>
    public static List<Match> Generate(int tournamentId, Group group, List<int> memberIds)
    {
        if (memberIds.Count != 4)
            throw new DomainException("Mỗi bảng phải có đúng 4 đơn vị");

        var (a, b, c, d) = (memberIds[0], memberIds[1], memberIds[2], memberIds[3]);

        return new List<Match>
        {
            // Vòng 1
            new() { TournamentId = tournamentId, GroupId = group.Id, Round = 1, MatchOrder = 1, Player1Id = a, Player2Id = b },
            new() { TournamentId = tournamentId, GroupId = group.Id, Round = 1, MatchOrder = 2, Player1Id = c, Player2Id = d },
            // Vòng 2
            new() { TournamentId = tournamentId, GroupId = group.Id, Round = 2, MatchOrder = 1, Player1Id = a, Player2Id = c },
            new() { TournamentId = tournamentId, GroupId = group.Id, Round = 2, MatchOrder = 2, Player1Id = b, Player2Id = d },
            // Vòng 3
            new() { TournamentId = tournamentId, GroupId = group.Id, Round = 3, MatchOrder = 1, Player1Id = a, Player2Id = d },
            new() { TournamentId = tournamentId, GroupId = group.Id, Round = 3, MatchOrder = 2, Player1Id = b, Player2Id = c },
        };
    }
}
```

### 2.3. Infrastructure Layer — `PickleballApp.Infrastructure`

```
PickleballApp.Infrastructure/
├── Data/
│   ├── AppDbContext.cs
│   ├── Configurations/             # EF Core Fluent API configurations
│   │   ├── UserConfiguration.cs
│   │   ├── TournamentConfiguration.cs
│   │   ├── ParticipantConfiguration.cs
│   │   ├── TeamConfiguration.cs
│   │   ├── GroupConfiguration.cs
│   │   ├── GroupMemberConfiguration.cs
│   │   ├── MatchConfiguration.cs
│   │   ├── CommunityGameConfiguration.cs
│   │   ├── ChatRoomConfiguration.cs
│   │   ├── MessageConfiguration.cs
│   │   ├── NotificationConfiguration.cs
│   │   └── FollowConfiguration.cs
│   └── Interceptors/
│       └── AuditableEntityInterceptor.cs  # Tự động set CreatedAt/UpdatedAt
├── Repositories/                   # (Optional nếu dùng DbContext trực tiếp)
├── Services/
│   ├── CurrentUserService.cs       # Lấy user từ HttpContext.User claims
│   ├── CacheService.cs             # Redis cache implementation
│   ├── FileStorageService.cs       # Cloudinary upload/download
│   ├── PushNotificationService.cs  # FCM integration
│   ├── EmailService.cs             # SMTP / SendGrid
│   └── JwtTokenService.cs          # Generate/validate JWT + Refresh Token
├── BackgroundJobs/
│   ├── RankingRecalculationJob.cs
│   ├── NotificationCleanupJob.cs
│   └── ExpiredTokenCleanupJob.cs
├── Migrations/
│   └── ... (EF Core migrations)
└── DependencyInjection.cs          # Extension method cho IServiceCollection
```

**Ví dụ DbContext:**

```csharp
// Data/AppDbContext.cs
public class AppDbContext : DbContext, IApplicationDbContext
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Tournament> Tournaments => Set<Tournament>();
    public DbSet<Participant> Participants => Set<Participant>();
    public DbSet<Team> Teams => Set<Team>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<GroupMember> GroupMembers => Set<GroupMember>();
    public DbSet<Match> Matches => Set<Match>();
    public DbSet<CommunityGame> CommunityGames => Set<CommunityGame>();
    public DbSet<GameParticipant> GameParticipants => Set<GameParticipant>();
    public DbSet<ChatRoom> ChatRooms => Set<ChatRoom>();
    public DbSet<ChatMember> ChatMembers => Set<ChatMember>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Follow> Follows => Set<Follow>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}
```

### 2.4. API Layer — `PickleballApp.API`

```
PickleballApp.API/
├── Controllers/
│   ├── AuthController.cs
│   ├── UsersController.cs
│   ├── TournamentsController.cs
│   ├── ParticipantsController.cs
│   ├── TeamsController.cs
│   ├── GroupsController.cs
│   ├── MatchesController.cs
│   ├── CommunityGamesController.cs
│   ├── ChatsController.cs
│   └── NotificationsController.cs
├── Hubs/
│   ├── TournamentHub.cs
│   ├── ChatHub.cs
│   └── NotificationHub.cs
├── Middleware/
│   ├── ExceptionHandlingMiddleware.cs
│   ├── RequestLoggingMiddleware.cs
│   └── RateLimitingMiddleware.cs
├── Filters/
│   ├── ValidationFilter.cs
│   └── TournamentCreatorFilter.cs    # Kiểm tra quyền Creator
├── Extensions/
│   ├── ServiceCollectionExtensions.cs
│   └── WebApplicationExtensions.cs
├── appsettings.json
├── appsettings.Development.json
├── appsettings.Production.json
└── Program.cs
```

**Ví dụ Controller:**

```csharp
// Controllers/TournamentsController.cs
[ApiController]
[Route("api/tournaments")]
[Authorize]
public class TournamentsController : ControllerBase
{
    private readonly ITournamentService _tournamentService;

    [HttpGet]
    public async Task<ActionResult<PagedResult<TournamentListDto>>> GetAll(
        [FromQuery] TournamentFilterParams filter)
        => Ok(await _tournamentService.GetAllAsync(filter));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<TournamentDto>> GetById(int id)
        => Ok(await _tournamentService.GetByIdAsync(id));

    [HttpPost]
    public async Task<ActionResult<TournamentDto>> Create(CreateTournamentRequest request)
    {
        var result = await _tournamentService.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpPut("{id:int}")]
    [ServiceFilter(typeof(TournamentCreatorFilter))]
    public async Task<ActionResult<TournamentDto>> Update(int id, UpdateTournamentRequest request)
        => Ok(await _tournamentService.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    [ServiceFilter(typeof(TournamentCreatorFilter))]
    public async Task<IActionResult> Delete(int id)
    {
        await _tournamentService.DeleteAsync(id);
        return NoContent();
    }

    [HttpPut("{id:int}/status")]
    [ServiceFilter(typeof(TournamentCreatorFilter))]
    public async Task<IActionResult> ChangeStatus(int id, [FromBody] TournamentStatus status)
    {
        await _tournamentService.ChangeStatusAsync(id, status);
        return NoContent();
    }
}
```

**Ví dụ Program.cs:**

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// === Services ===
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c => { /* JWT Bearer config */ });

// Application layer DI
builder.Services.AddApplicationServices();

// Infrastructure layer DI
builder.Services.AddInfrastructureServices(builder.Configuration);

// SignalR
builder.Services.AddSignalR()
    .AddStackExchangeRedis(builder.Configuration.GetConnectionString("Redis")!);

// Authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };

        // SignalR JWT: đọc token từ query string
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                    context.Token = accessToken;
                return Task.CompletedTask;
            }
        };
    });

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
                builder.Configuration.GetSection("Cors:Origins").Get<string[]>()!)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials(); // Required cho SignalR
    });
});

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("auth", opt =>
    {
        opt.PermitLimit = 5;
        opt.Window = TimeSpan.FromMinutes(15);
    });
    options.AddFixedWindowLimiter("api", opt =>
    {
        opt.PermitLimit = 100;
        opt.Window = TimeSpan.FromMinutes(1);
    });
});

// Health Checks
builder.Services.AddHealthChecks()
    .AddNpgSql(builder.Configuration.GetConnectionString("Database")!)
    .AddRedis(builder.Configuration.GetConnectionString("Redis")!)
    .AddUrlGroup(new Uri("https://fcm.googleapis.com"), "FCM");

var app = builder.Build();

// === Middleware Pipeline ===
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseMiddleware<RequestLoggingMiddleware>();

app.UseHttpsRedirection();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<TournamentHub>("/hubs/tournament");
app.MapHub<ChatHub>("/hubs/chat");
app.MapHub<NotificationHub>("/hubs/notification");
app.MapHealthChecks("/health");

app.Run();
```

---

## 3. Cross-Cutting Concerns

### 3.1. Exception Handling

```csharp
// Middleware/ExceptionHandlingMiddleware.cs
public class ExceptionHandlingMiddleware
{
    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            var (statusCode, response) = ex switch
            {
                ValidationException ve => (400, new ProblemDetails
                {
                    Title = "Validation Error",
                    Status = 400,
                    Extensions = { ["errors"] = ve.Errors }
                }),
                NotFoundException nf => (404, new ProblemDetails
                {
                    Title = "Not Found",
                    Detail = nf.Message,
                    Status = 404
                }),
                ForbiddenException => (403, new ProblemDetails
                {
                    Title = "Forbidden",
                    Status = 403
                }),
                DomainException de => (422, new ProblemDetails
                {
                    Title = "Business Rule Violation",
                    Detail = de.Message,
                    Status = 422
                }),
                _ => (500, new ProblemDetails
                {
                    Title = "Internal Server Error",
                    Status = 500
                })
            };

            context.Response.StatusCode = statusCode;
            await context.Response.WriteAsJsonAsync(response);
        }
    }
}
```

### 3.2. Validation — FluentValidation

```csharp
// Tournaments/Validators/CreateTournamentValidator.cs
public class CreateTournamentValidator : AbstractValidator<CreateTournamentRequest>
{
    public CreateTournamentValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Tên giải đấu không được để trống")
            .MaximumLength(200);

        RuleFor(x => x.Type)
            .IsInEnum().WithMessage("Loại giải phải là Singles hoặc Doubles");

        RuleFor(x => x.NumGroups)
            .InclusiveBetween(1, 4).When(x => x.Type == TournamentType.Singles)
            .WithMessage("Đấu đơn: 1-4 bảng");

        RuleFor(x => x.NumGroups)
            .InclusiveBetween(1, 2).When(x => x.Type == TournamentType.Doubles)
            .WithMessage("Đấu đôi: 1-2 bảng");

        RuleFor(x => x.ScoringFormat)
            .IsInEnum();
    }
}
```

### 3.3. Logging — Serilog

```json
// appsettings.json
{
  "Serilog": {
    "Using": ["Serilog.Sinks.Console", "Serilog.Sinks.Seq"],
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.EntityFrameworkCore": "Warning"
      }
    },
    "WriteTo": [
      { "Name": "Console" },
      { "Name": "Seq", "Args": { "serverUrl": "http://seq:5341" } }
    ],
    "Enrich": ["FromLogContext", "WithMachineName", "WithThreadId"]
  }
}
```

### 3.4. API Response Format chuẩn

```
// Thành công
{
  "data": { ... },
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 45,
    "totalPages": 3
  }
}

// Lỗi — RFC 7807 Problem Details
{
  "type": "https://tools.ietf.org/html/rfc7807",
  "title": "Validation Error",
  "status": 400,
  "detail": "Một hoặc nhiều lỗi validation xảy ra",
  "errors": {
    "Name": ["Tên giải đấu không được để trống"],
    "NumGroups": ["Đấu đơn: 1-4 bảng"]
  }
}
```

---

## 4. Realtime — SignalR

### 4.1. TournamentHub

```csharp
// Hubs/TournamentHub.cs
[Authorize]
public class TournamentHub : Hub
{
    public async Task JoinTournament(Guid tournamentId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"tournament:{tournamentId}");
    }

    public async Task LeaveTournament(Guid tournamentId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"tournament:{tournamentId}");
    }

    // Gọi từ MatchService khi nhập điểm
    public static async Task BroadcastScoreUpdate(
        IHubContext<TournamentHub> hub, Guid tournamentId, MatchDto match)
    {
        await hub.Clients.Group($"tournament:{tournamentId}")
            .SendAsync("ScoreUpdated", match);
    }

    public static async Task BroadcastStandingsUpdate(
        IHubContext<TournamentHub> hub, Guid tournamentId, Guid groupId, StandingsDto standings)
    {
        await hub.Clients.Group($"tournament:{tournamentId}")
            .SendAsync("StandingsUpdated", new { groupId, standings });
    }
}
```

### 4.2. ChatHub

```csharp
// Hubs/ChatHub.cs
[Authorize]
public class ChatHub : Hub
{
    private readonly IChatService _chatService;

    public async Task SendMessage(Guid roomId, string content, MessageType type = MessageType.Text)
    {
        var userId = Guid.Parse(Context.User!.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        var message = await _chatService.SendMessageAsync(roomId, userId, content, type);

        await Clients.Group($"chat:{roomId}").SendAsync("MessageReceived", message);
    }

    public async Task TypingStart(Guid roomId)
    {
        var userId = Guid.Parse(Context.User!.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        await Clients.OthersInGroup($"chat:{roomId}").SendAsync("UserTyping", roomId, userId);
    }

    public async Task TypingStop(Guid roomId)
    {
        var userId = Guid.Parse(Context.User!.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        await Clients.OthersInGroup($"chat:{roomId}").SendAsync("UserStoppedTyping", roomId, userId);
    }

    public override async Task OnConnectedAsync()
    {
        var userId = Guid.Parse(Context.User!.FindFirst(ClaimTypes.NameIdentifier)!.Value);
        var rooms = await _chatService.GetUserRoomIdsAsync(userId);
        foreach (var roomId in rooms)
            await Groups.AddToGroupAsync(Context.ConnectionId, $"chat:{roomId}");
    }
}
```

### 4.3. NotificationHub

```csharp
// Hubs/NotificationHub.cs
[Authorize]
public class NotificationHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.User!.FindFirst(ClaimTypes.NameIdentifier)!.Value;
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
    }

    // Gọi từ NotificationService
    public static async Task SendToUser(
        IHubContext<NotificationHub> hub, Guid userId, NotificationDto notification)
    {
        await hub.Clients.Group($"user:{userId}")
            .SendAsync("NewNotification", notification);
    }
}
```

### 4.4. SignalR Scale-out với Redis

```csharp
// Program.cs — đã config ở trên
builder.Services.AddSignalR()
    .AddStackExchangeRedis(builder.Configuration.GetConnectionString("Redis")!, options =>
    {
        options.Configuration.ChannelPrefix = RedisChannel.Literal("PickleballApp");
    });
```

Khi chạy nhiều instance API, Redis Backplane đảm bảo message được gửi đến tất cả clients bất kể đang kết nối vào instance nào.

---

## 5. Background Jobs & Queue

### 5.1. Sử dụng .NET BackgroundService (đơn giản, Phase 1)

```csharp
// BackgroundJobs/RankingRecalculationJob.cs
public class RankingRecalculationJob : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly Channel<Guid> _channel; // tournamentId cần tính lại

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await foreach (var tournamentId in _channel.Reader.ReadAllAsync(ct))
        {
            using var scope = _scopeFactory.CreateScope();
            var standingsService = scope.ServiceProvider.GetRequiredService<IStandingsService>();
            await standingsService.RecalculateAsync(tournamentId);
        }
    }
}
```

### 5.2. Các Job cần xử lý

| Job | Trigger | Mô tả |
|-----|---------|--------|
| `RankingRecalculationJob` | Sau khi nhập/sửa điểm | Tính lại BXH bảng + kiểm tra giải hoàn thành |
| `NotificationDispatchJob` | Khi có event mới | Gửi push notification qua FCM + lưu in-app notification |
| `ExpiredTokenCleanupJob` | Hàng ngày (cron) | Xóa refresh tokens đã hết hạn |
| `NotificationCleanupJob` | Hàng tuần (cron) | Xóa notifications cũ hơn 90 ngày |
| `ImageResizeJob` | Upload avatar/banner | Resize + compress trước khi lưu Cloudinary |

### 5.3. Nâng cấp lên RabbitMQ (Phase 2+, nếu cần)

```
Producer (API) → RabbitMQ Exchange → Queue → Consumer (Worker Service)

Queues:
  - ranking.recalculate
  - notification.push
  - image.resize
```

---

## 6. Caching Strategy

### 6.1. Redis Cache Layers

| Key Pattern | TTL | Mô tả | Invalidation |
|-------------|-----|--------|--------------|
| `tournaments:list:{filterHash}` | 5 phút | Danh sách giải đấu | Khi tạo/sửa/hủy giải |
| `tournament:{id}` | 10 phút | Chi tiết 1 giải | Khi sửa giải |
| `tournament:{id}:standings:{groupId}` | 1 phút | BXH bảng | Khi nhập/sửa điểm |
| `tournament:{id}:matches` | 5 phút | Lịch thi đấu | Khi nhập/sửa điểm |
| `user:{id}:profile` | 30 phút | Profile user | Khi sửa profile |
| `user:{id}:unread-count` | Realtime | Số thông báo chưa đọc | Khi có notification mới / đọc |

### 6.2. Cache Implementation

```csharp
// Services/CacheService.cs
public class CacheService : ICacheService
{
    private readonly IDistributedCache _cache;
    private readonly IConnectionMultiplexer _redis;

    public async Task<T?> GetOrSetAsync<T>(string key, Func<Task<T>> factory, TimeSpan ttl)
    {
        var cached = await _cache.GetStringAsync(key);
        if (cached != null)
            return JsonSerializer.Deserialize<T>(cached);

        var value = await factory();
        await _cache.SetStringAsync(key,
            JsonSerializer.Serialize(value),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = ttl });
        return value;
    }

    public async Task RemoveByPrefixAsync(string prefix)
    {
        var server = _redis.GetServer(_redis.GetEndPoints().First());
        var keys = server.Keys(pattern: $"{prefix}*").ToArray();
        if (keys.Length > 0)
        {
            var db = _redis.GetDatabase();
            await db.KeyDeleteAsync(keys);
        }
    }
}
```

---

## 7. File Storage

### 7.1. Cloudinary Service (Miễn phí)

> **Tại sao chọn Cloudinary?** Gói miễn phí cung cấp 25 credits/tháng (~25 GB storage + transformations), tự động resize/crop/optimize hình ảnh qua URL, không cần tự host.

```csharp
// Services/FileStorageService.cs
// NuGet: CloudinaryDotNet
public class FileStorageService : IFileStorageService
{
    private readonly Cloudinary _cloudinary;

    public FileStorageService(IOptions<CloudinarySettings> options)
    {
        var account = new Account(
            options.Value.CloudName,
            options.Value.ApiKey,
            options.Value.ApiSecret);
        _cloudinary = new Cloudinary(account);
    }

    public async Task<string> UploadAsync(Stream stream, string fileName, string contentType)
    {
        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(fileName, stream),
            Folder = $"pickleball/{DateTime.UtcNow:yyyy/MM}",
            Transformation = new Transformation()
                .Quality("auto").FetchFormat("auto") // Tự động tối ưu
        };

        var result = await _cloudinary.UploadAsync(uploadParams);
        return result.SecureUrl.ToString();
    }

    public async Task DeleteAsync(string fileUrl)
    {
        var publicId = ExtractPublicIdFromUrl(fileUrl);
        await _cloudinary.DestroyAsync(new DeletionParams(publicId));
    }
}
```

### 7.2. Image Processing

```csharp
// Dùng SkiaSharp hoặc ImageSharp
public static class ImageProcessor
{
    public static Stream ResizeAndCompress(Stream input, int maxWidth, int maxHeight, int quality = 80)
    {
        using var image = Image.Load(input);
        image.Mutate(x => x.Resize(new ResizeOptions
        {
            Size = new Size(maxWidth, maxHeight),
            Mode = ResizeMode.Max
        }));

        var output = new MemoryStream();
        image.SaveAsWebP(output, new WebPEncoder { Quality = quality });
        output.Position = 0;
        return output;
    }
}
```

### 7.3. Upload Policies

| Loại file | Max size | Kích thước output | Format |
|-----------|---------|-------------------|--------|
| Avatar | 5 MB | 256x256 | WebP |
| Banner giải đấu | 10 MB | 1200x630 | WebP |
| Ảnh chứng minh điểm | 10 MB | 1920x1080 (max) | WebP |

---

## 8. DevOps & CI/CD

### 8.1. Docker

**Backend Dockerfile:**

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["src/PickleballApp.API/PickleballApp.API.csproj", "src/PickleballApp.API/"]
COPY ["src/PickleballApp.Application/PickleballApp.Application.csproj", "src/PickleballApp.Application/"]
COPY ["src/PickleballApp.Domain/PickleballApp.Domain.csproj", "src/PickleballApp.Domain/"]
COPY ["src/PickleballApp.Infrastructure/PickleballApp.Infrastructure.csproj", "src/PickleballApp.Infrastructure/"]
RUN dotnet restore "src/PickleballApp.API/PickleballApp.API.csproj"

COPY . .
RUN dotnet publish "src/PickleballApp.API/PickleballApp.API.csproj" \
    -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

RUN adduser --disabled-password --gecos "" appuser
USER appuser

COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "PickleballApp.API.dll"]
```

**Docker Compose (Development):**

```yaml
# docker-compose.yml
version: "3.8"

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__Database=Host=postgres;Database=pickleball;Username=postgres;Password=postgres
      - ConnectionStrings__Redis=redis:6379
      - Jwt__Key=${JWT_KEY}
      - Jwt__Issuer=PickleballApp
      - Jwt__Audience=PickleballApp
      - Cloudinary__CloudName=your-cloud-name
      - Cloudinary__ApiKey=your-api-key
      - Cloudinary__ApiSecret=your-api-secret
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: pickleball
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

  seq:
    image: datalust/seq:latest
    ports:
      - "5341:5341"
      - "8081:80"
    environment:
      ACCEPT_EULA: "Y"

volumes:
  postgres_data:
```

### 8.2. CI/CD Pipeline — GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [develop, main]
  pull_request:
    branches: [develop]

env:
  DOTNET_VERSION: "8.0.x"
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/api

jobs:
  # ─── BUILD & TEST ─────────────────────────
  build-and-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: pickleball_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore -c Release

      - name: Unit Tests
        run: dotnet test tests/PickleballApp.UnitTests --no-build -c Release --logger trx

      - name: Integration Tests
        run: dotnet test tests/PickleballApp.IntegrationTests --no-build -c Release --logger trx
        env:
          ConnectionStrings__Database: Host=localhost;Database=pickleball_test;Username=postgres;Password=postgres
          ConnectionStrings__Redis: localhost:6379

      - name: Publish Test Results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Test Results
          path: "**/*.trx"
          reporter: dotnet-trx

  # ─── CODE QUALITY ─────────────────────────
  code-quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Format Check
        run: dotnet format --verify-no-changes

  # ─── DOCKER BUILD & PUSH ──────────────────
  docker:
    needs: [build-and-test, code-quality]
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

  # ─── DEPLOY TO STAGING ────────────────────
  deploy-staging:
    needs: docker
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Deploy to staging
        run: |
          # SSH deploy hoặc kubectl apply hoặc docker compose pull
          echo "Deploying to staging..."

  # ─── DEPLOY TO PRODUCTION ─────────────────
  deploy-production:
    needs: docker
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy to production
        run: |
          echo "Deploying to production..."
```

### 8.3. Database Migration Strategy

```bash
# Tạo migration mới
dotnet ef migrations add AddTournamentTable \
  --project src/PickleballApp.Infrastructure \
  --startup-project src/PickleballApp.API

# Áp dụng migration
dotnet ef database update \
  --project src/PickleballApp.Infrastructure \
  --startup-project src/PickleballApp.API

# Tạo migration SQL script (cho production)
dotnet ef migrations script \
  --project src/PickleballApp.Infrastructure \
  --startup-project src/PickleballApp.API \
  --idempotent \
  -o migrations.sql
```

**Production Migration:**
- KHÔNG chạy `ef database update` trực tiếp trên production
- Export SQL script → review → chạy thủ công hoặc qua CI/CD approved step
- Sử dụng flag `--idempotent` để script an toàn khi chạy lại

---

## 9. Hạ Tầng Triển Khai

### 9.1. Environments

| Môi trường | Mục đích | Hạ tầng |
|------------|---------|---------|
| **Local** | Development | Docker Compose (API + PG + Redis + Seq), Cloudinary (cloud) |
| **Staging** | Testing, QA | VPS / Cloud VM (Docker Compose) |
| **Production** | Live | Cloud VM hoặc Kubernetes |

### 9.2. Architecture cho Production (Option A: VPS đơn giản)

```
                        ┌─────────────────┐
                        │   Cloudflare     │  DNS + CDN + SSL
                        │   (hoặc Nginx)  │
                        └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │  Nginx Reverse  │  Load balancer
                        │  Proxy          │  + SSL termination
                        └────────┬────────┘
                    ┌────────────┼────────────┐
               ┌────▼────┐ ┌────▼────┐ ┌────▼────┐
               │  API-1  │ │  API-2  │ │  API-3  │  .NET 8 containers
               └────┬────┘ └────┬────┘ └────┬────┘
                    └────────────┼────────────┘
                    ┌────────────┼────────────┐
               ┌────▼────┐ ┌────▼────┐ ┌────▼────┐
               │PostgreSQL│ │  Redis  │
               │(Primary) │ │         │
               └─────────┘ └─────────┘  + Cloudinary (Cloud, miễn phí)
```

### 9.3. Architecture cho Production (Option B: Cloud-native)

```
                        ┌─────────────────┐
                        │  AWS ALB / GCP   │
                        │  Load Balancer   │
                        └────────┬────────┘
                                 │
                   ┌─────────────┼─────────────┐
              ┌────▼────┐  ┌────▼────┐  ┌─────▼────┐
              │ ECS/GKE │  │ ECS/GKE │  │ ECS/GKE  │
              │ API Pod │  │ API Pod │  │ API Pod  │
              └────┬────┘  └────┬────┘  └────┬─────┘
                   └─────────────┼─────────────┘
                   ┌─────────────┼─────────────┐
              ┌────▼────┐  ┌────▼────┐  ┌─────▼────┐
              │ RDS     │  │ElastiC. │
              │PostgreSQL│  │ Redis  │  + Cloudinary (Cloud, miễn phí)
              └─────────┘  └─────────┘
```

### 9.4. Nginx Config

```nginx
# /etc/nginx/sites-available/pickleball-api
upstream api_servers {
    server 127.0.0.1:5001;
    server 127.0.0.1:5002;
}

server {
    listen 443 ssl http2;
    server_name api.pickleball-app.com;

    ssl_certificate     /etc/letsencrypt/live/api.pickleball-app.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.pickleball-app.com/privkey.pem;

    # REST API
    location /api/ {
        proxy_pass http://api_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # SignalR WebSocket
    location /hubs/ {
        proxy_pass http://api_servers;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;  # 24 giờ cho WebSocket
    }

    # Health check
    location /health {
        proxy_pass http://api_servers;
    }
}
```

### 9.5. Environment Variables (Production)

```bash
# .env.production (KHÔNG commit vào git)
ASPNETCORE_ENVIRONMENT=Production

# Database
ConnectionStrings__Database=Host=db.internal;Database=pickleball;Username=app;Password=***;SSL Mode=Require

# Redis
ConnectionStrings__Redis=redis.internal:6379,password=***,ssl=True

# JWT
Jwt__Key=<random-256-bit-key>
Jwt__Issuer=PickleballApp
Jwt__Audience=PickleballApp
Jwt__AccessTokenExpirationMinutes=15
Jwt__RefreshTokenExpirationDays=7

# Cloudinary (Miễn phí)
Cloudinary__CloudName=your-cloud-name
Cloudinary__ApiKey=***
Cloudinary__ApiSecret=***

# FCM
Fcm__ProjectId=pickleball-app
Fcm__CredentialsPath=/secrets/firebase-credentials.json

# CORS
Cors__Origins__0=https://pickleball-app.com
Cors__Origins__1=https://admin.pickleball-app.com
```

---

## 10. Monitoring & Observability

### 10.1. Stack giám sát

| Thành phần | Công cụ | Mục đích |
|-----------|---------|---------|
| **Logging** | Serilog → Seq (hoặc ELK) | Structured logs, search, dashboard |
| **Metrics** | Prometheus + Grafana | API latency, request rate, error rate |
| **Error Tracking** | Sentry | Exception tracking, alerting |
| **Health Checks** | ASP.NET Health Checks | Kiểm tra DB, Redis, FCM |
| **Uptime** | UptimeRobot / Grafana OnCall | Alert khi service down |

### 10.2. Health Check Endpoints

```
GET /health          → 200 OK (tất cả healthy) / 503 (có service down)
GET /health/ready    → Kiểm tra DB + Redis
GET /health/live     → Kiểm tra process đang chạy
```

### 10.3. Key Metrics cần theo dõi

| Metric | Ngưỡng cảnh báo | Mô tả |
|--------|-----------------|--------|
| API Response Time (p95) | > 500ms | Thời gian phản hồi |
| API Error Rate (5xx) | > 1% | Tỉ lệ lỗi server |
| DB Connection Pool | > 80% used | Pool kết nối DB |
| Redis Memory | > 80% | Bộ nhớ cache |
| SignalR Connections | > 10,000 | Số kết nối WebSocket |
| CPU Usage | > 80% | Sử dụng CPU |
| Memory Usage | > 85% | Sử dụng RAM |
| Disk Usage | > 90% | Dung lượng đĩa |

### 10.4. Alerting

```yaml
# Prometheus alert rules (ví dụ)
groups:
  - name: pickleball-api
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "API error rate > 1%"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "API p95 latency > 500ms"
```

---

## 11. Bảo Mật

### 11.1. Authentication Flow

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│  Client  │────────>│   API    │────────>│    DB    │
└──────────┘         └──────────┘         └──────────┘

1. POST /api/auth/login { email, password }
2. API validate credentials
3. API generate: Access Token (JWT, 15 phút) + Refresh Token (opaque, 7 ngày)
4. Client lưu:
   - Access Token → Memory (web) / SecureStore (mobile)
   - Refresh Token → HttpOnly Cookie (web) / SecureStore (mobile)
5. Mỗi request: Authorization: Bearer <access_token>
6. Khi access token hết hạn:
   - POST /api/auth/refresh { refreshToken }
   - API verify refresh token → issue new pair
7. Logout: DELETE refresh token from DB + Cookie
```

### 11.2. Security Checklist

| Hạng mục | Biện pháp |
|---------|----------|
| **Password** | bcrypt, cost factor 12, validate policy (8+ ký tự, chữ hoa, số, đặc biệt) |
| **JWT** | HS256 (hoặc RS256 nếu microservice), short-lived (15 phút) |
| **Refresh Token** | Opaque string, lưu DB, hash trước khi lưu, rotation (mỗi lần dùng tạo mới) |
| **Rate Limiting** | Login: 5 req/15 phút/IP. API chung: 100 req/phút/user |
| **CORS** | Whitelist explicit origins, AllowCredentials chỉ cho trusted origins |
| **Input Validation** | FluentValidation trên mọi request DTO |
| **SQL Injection** | EF Core parameterized queries (default) |
| **XSS** | Content-Type headers, CSP headers |
| **HTTPS** | Enforce everywhere, HSTS header |
| **File Upload** | Validate MIME type, max size, virus scan (optional) |
| **Secrets** | Không commit vào git, dùng env vars hoặc Secret Manager |

### 11.3. Authorization — Policy-based

```csharp
// Policies
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("TournamentCreator", policy =>
        policy.RequireAssertion(context =>
        {
            // Kiểm tra trong TournamentCreatorFilter
            return true; // Logic nằm trong filter
        }));
});
```

---

## 12. Quy Ước Lập Trình

### 12.1. Naming Conventions

| Loại | Convention | Ví dụ |
|------|-----------|-------|
| Class, Interface | PascalCase | `TournamentService`, `ITournamentService` |
| Method | PascalCase | `GetByIdAsync()` |
| Property | PascalCase | `CreatorId` |
| Parameter, Local variable | camelCase | `tournamentId`, `currentUser` |
| Private field | _camelCase | `_dbContext`, `_cache` |
| Constant | PascalCase | `MaxGroupsForSingles = 4` |
| Enum value | PascalCase | `TournamentStatus.InProgress` |

### 12.2. Async Convention

- Tất cả method I/O phải async
- Suffix `Async` cho async methods
- Luôn truyền `CancellationToken` qua controller đến service

### 12.3. API Convention

- URL: kebab-case → `/api/tournaments/:id/groups`
- HTTP verbs: GET (đọc), POST (tạo), PUT (cập nhật toàn bộ), PATCH (cập nhật 1 phần), DELETE (xóa)
- Response: 200 (OK), 201 (Created), 204 (No Content), 400 (Bad Request), 401 (Unauthorized), 403 (Forbidden), 404 (Not Found), 422 (Unprocessable Entity), 429 (Too Many Requests), 500 (Server Error)

### 12.4. Git Branch Strategy

```
main ─────────────────────────────────── (production, protected)
  │
  └── develop ────────────────────────── (staging, integration)
        │
        ├── feature/tournament-crud ──── (feature branches)
        ├── feature/match-scoring
        ├── fix/score-validation
        └── agent/YYYYMMDD-slug ──────── (agent-created branches)
```

### 12.5. Commit Message Convention

```
<type>(<scope>): <subject>

feat(tournament): add create tournament API
fix(match): correct score validation for deuce
refactor(auth): extract JWT logic to separate service
docs(api): update Swagger descriptions
test(standings): add tiebreaker unit tests
chore(docker): update postgres to v16
```
