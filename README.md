# 🏆 Sports Betting Dashboard

A Windows Server application that fetches the **top 10 most competitive betting events of the day** across major sports leagues, stores them in **Microsoft SQL Server**, and serves a live **IIS dashboard** — rebuilt every 24 hours automatically.

![Dashboard Preview](https://img.shields.io/badge/IIS-Dashboard-00d4aa?style=flat-square&logo=windows)
![C++](https://img.shields.io/badge/C%2B%2B-17-blue?style=flat-square&logo=cplusplus)
![MSSQL](https://img.shields.io/badge/MSSQL-2019-red?style=flat-square&logo=microsoftsqlserver)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## 📐 Architecture

```
The Odds API (free tier)
        │
        │  HTTPS — daily at 06:00 AM
        ▼
┌─────────────────────────────┐
│  C++ Fetcher                │  SportsBettingFetcher.exe
│  - Queries 10 sport leagues │  Windows Task Scheduler
│  - Ranks by match balance   │
│  - Upserts top 10 to DB     │
└────────────┬────────────────┘
             │ ODBC / Windows Auth
             ▼
┌─────────────────────────────┐
│  Microsoft SQL Server       │  Instance: IDOLMSSQL
│  Database: SportsBetting    │  Table: BettingEvents
│  View: vw_TodayTop10        │
└────────────┬────────────────┘
             │ ODBC / Windows Auth
             ▼
┌─────────────────────────────┐
│  IIS ASP Classic Dashboard  │  http://localhost:8090
│  - Dark themed UI           │  Auto-refreshes hourly
│  - Shows odds pills         │
│  - Ranked by competitiveness│
└─────────────────────────────┘
```

---

## 🏅 Sports Covered

| League | Key |
|--------|-----|
| NBA Basketball | `basketball_nba` |
| NHL Hockey | `icehockey_nhl` |
| NFL Football | `americanfootball_nfl` |
| MLB Baseball | `baseball_mlb` |
| English Premier League | `soccer_epl` |
| UEFA Champions League | `soccer_uefa_champs_league` |
| NCAA Basketball | `basketball_ncaab` |
| NCAA Football | `americanfootball_ncaaf` |
| MMA | `mma_mixed_martial_arts` |
| ATP Tennis | `tennis_atp_us_open` |

---

## 🛠 Prerequisites

| Requirement | Notes |
|-------------|-------|
| Windows Server 2019/2022 | Or Windows 10/11 |
| Visual Studio 2022 (any edition) | C++ Desktop workload required |
| [vcpkg](https://github.com/microsoft/vcpkg) | Package manager for C++ deps |
| Microsoft SQL Server | Any edition; named or default instance |
| ODBC Driver 17 for SQL Server | [Download](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server) |
| IIS with ASP Classic | Enabled via Windows Features |
| [The Odds API Key](https://the-odds-api.com) | Free tier: 500 requests/month |

---

## 🚀 Installation

### 1. Clone the repo
```powershell
git clone https://github.com/YOUR_USERNAME/SportsBettingApp.git C:\SportsBettingApp
cd C:\SportsBettingApp
```

### 2. Install C++ dependencies via vcpkg
```powershell
git clone https://github.com/microsoft/vcpkg C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
C:\vcpkg\vcpkg install curl:x64-windows nlohmann-json:x64-windows
```

### 3. Set your API key
Edit `main.cpp` line 34 — replace the placeholder:
```cpp
const std::string ODDS_API_KEY = "YOUR_API_KEY_HERE";
```
Get a free key at [the-odds-api.com](https://the-odds-api.com).

> ⚠️ **Never commit your API key.** `main.cpp` is tracked by git — use environment variables or a local `secrets.h` file excluded via `.gitignore` for production.

### 4. Update the SQL Server instance name
Edit `main.cpp` line 38 if your SQL Server instance differs:
```cpp
const std::string DB_CONN_STR =
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost\\YOUR_INSTANCE;"   // <-- change this
    "DATABASE=SportsBetting;"
    "Trusted_Connection=yes;";
```
Find your instance name with:
```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" -Name InstalledInstances
```

### 5. Build the C++ fetcher
```powershell
.\build.bat
```
Output: `SportsBettingFetcher.exe`

### 6. Copy runtime DLLs next to the EXE
```powershell
Copy-Item "C:\vcpkg\installed\x64-windows\bin\libcurl.dll" "C:\SportsBettingApp\"
Copy-Item "C:\vcpkg\installed\x64-windows\bin\zlib1.dll"   "C:\SportsBettingApp\"
```

### 7. Create the database
```powershell
sqlcmd -S localhost\YOUR_INSTANCE -E -i C:\SportsBettingApp\setup.sql
```

### 8. Configure IIS (Administrator)
```powershell
.\configure_iis.bat
```
Serves the dashboard at `http://localhost:8090`.

### 9. Grant IIS SQL Server access (Administrator)
```powershell
sqlcmd -S localhost\YOUR_INSTANCE -E -Q "
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'NT AUTHORITY\IUSR')
    CREATE LOGIN [NT AUTHORITY\IUSR] FROM WINDOWS;
USE SportsBetting;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'NT AUTHORITY\IUSR')
    CREATE USER [NT AUTHORITY\IUSR] FOR LOGIN [NT AUTHORITY\IUSR];
ALTER ROLE db_datareader ADD MEMBER [NT AUTHORITY\IUSR];
ALTER ROLE db_datareader ADD MEMBER [NT AUTHORITY\NETWORK SERVICE];
"
```

### 10. Register auto-start and scheduled tasks (Administrator)
```powershell
.\persist.bat
```
This configures:
- SQL Server → auto-start
- IIS → auto-start
- App pool → AlwaysRunning
- `SportsBettingFetcher` → daily at 06:00 AM
- `SportsBettingStartup` → runs on every boot

### 11. Test immediately
```powershell
.\SportsBettingFetcher.exe
```
Then open: **http://localhost:8090**

---

## 📁 File Structure

```
SportsBettingApp/
├── main.cpp                 # C++ fetcher source code
├── build.bat                # MSVC build script
├── setup.sql                # SQL Server schema (DB, table, view, permissions)
├── configure_iis.bat        # IIS site + app pool setup
├── persist.bat              # Auto-start registration (run once as Admin)
├── startup.bat              # Boot-time service health check
├── fix_iis_auth.bat         # IIS authentication fix helper
├── register_task.bat        # Manual task scheduler registration
├── .gitignore               # Excludes binaries, logs, secrets
└── README.md                # This file

C:\inetpub\sportsbetting\
└── index.asp                # IIS dashboard (ASP Classic)
```

---

## ⚙️ Configuration Reference

| Setting | Location | Default |
|---------|----------|---------|
| API Key | `main.cpp` line 34 | *(required)* |
| SQL Server instance | `main.cpp` line 38 | `localhost\IDOLMSSQL` |
| SQL Server instance | `index.asp` line 12 | `localhost\IDOLMSSQL` |
| IIS port | `configure_iis.bat` | `8090` |
| Fetch time | `persist.bat` / `register_task.bat` | `06:00 AM daily` |
| Log file | `main.cpp` line 42 | `C:\SportsBettingApp\fetcher.log` |

---

## 🗄️ Database Schema

```sql
TABLE BettingEvents (
    Id            INT IDENTITY PRIMARY KEY,
    EventId       NVARCHAR(64),   -- Unique ID from The Odds API
    SportKey      NVARCHAR(64),   -- e.g. basketball_nba
    SportTitle    NVARCHAR(128),  -- e.g. NBA
    CommenceTime  NVARCHAR(32),   -- ISO 8601
    HomeTeam      NVARCHAR(128),
    AwayTeam      NVARCHAR(128),
    HomeOdds      FLOAT,          -- Decimal format
    AwayOdds      FLOAT,
    DrawOdds      FLOAT,          -- Soccer only
    Bookmaker     NVARCHAR(64),
    FetchDate     DATE,           -- Partition key
    CreatedAt     DATETIME
)
```

Events are ranked by `ABS(HomeOdds - AwayOdds)` — the most evenly matched (competitive) games rank highest.

---

## 🔧 Troubleshooting

**Fetcher exits with no log file**
→ Missing DLLs. Copy `libcurl.dll` and `zlib1.dll` from `C:\vcpkg\installed\x64-windows\bin\` next to the EXE.

**`FATAL: Cannot connect to database`**
→ Wrong instance name in `DB_CONN_STR`. Run `setup.sql` first, rebuild after editing `main.cpp`.

**IIS shows `Error loading data`**
→ IIS account lacks SQL login. Re-run the `sqlcmd` grant command in step 9.

**`EXCEEDED_FREQ_LIMIT` in log**
→ API called too frequently. The daily scheduler prevents this — only run manually when needed.

**Dashboard shows no events**
→ Run `.\SportsBettingFetcher.exe` manually to populate today's data.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Credits

- Live odds data: [The Odds API](https://the-odds-api.com)
- HTTP client: [libcurl](https://curl.se/libcurl/)
- JSON parsing: [nlohmann/json](https://github.com/nlohmann/json)
