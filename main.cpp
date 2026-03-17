/*
 * SportsBettingFetcher - C++ Application
 * Fetches top 10 betting sports events for the day from The Odds API
 * Stores results in MSSQL database
 * Designed to run daily via Windows Task Scheduler
 *
 * Dependencies:
 *   - libcurl (HTTP requests)
 *   - nlohmann/json (JSON parsing)
 *   - ODBC / SQL Server Native Client (DB writes)
 *
 * Build: See build.bat
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <sql.h>
#include <sqlext.h>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <fstream>
#include <ctime>
#include <algorithm>

using json = nlohmann::json;

// ─── Configuration ────────────────────────────────────────────────────────────
// Replace with your actual Odds API key (free tier at https://the-odds-api.com)
const std::string ODDS_API_KEY   = "72f57c4203af9c856c8bc985ef69d676";
const std::string ODDS_API_BASE  = "https://api.the-odds-api.com/v4";

// MSSQL connection string — named instance IDOLMSSQL
const std::string DB_CONN_STR =
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost\\IDOLMSSQL;"
    "DATABASE=SportsBetting;"
    "Trusted_Connection=yes;";

const std::string LOG_FILE = "C:\\SportsBettingApp\\fetcher.log";

// ─── Logging ──────────────────────────────────────────────────────────────────
void log(const std::string& msg) {
    std::ofstream f(LOG_FILE, std::ios::app);
    time_t now = time(nullptr);
    char ts[32];
    strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", localtime(&now));
    f << "[" << ts << "] " << msg << "\n";
    std::cout << "[" << ts << "] " << msg << "\n";
}

// ─── HTTP Helper ──────────────────────────────────────────────────────────────
static size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* output) {
    size_t total = size * nmemb;
    output->append((char*)contents, total);
    return total;
}

std::string httpGet(const std::string& url) {
    CURL* curl = curl_easy_init();
    std::string response;
    if (!curl) {
        log("ERROR: curl_easy_init failed");
        return "";
    }
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "SportsBettingApp/1.0");

    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        log(std::string("ERROR: curl_easy_perform: ") + curl_easy_strerror(res));
        response = "";
    }
    curl_easy_cleanup(curl);
    return response;
}

// ─── Data Model ───────────────────────────────────────────────────────────────
struct BettingEvent {
    std::string event_id;
    std::string sport_key;
    std::string sport_title;
    std::string commence_time;
    std::string home_team;
    std::string away_team;
    double      home_odds     = 0.0;
    double      away_odds     = 0.0;
    double      draw_odds     = 0.0;
    std::string bookmaker;
    std::string fetch_date;
};

// ─── MSSQL Helpers ────────────────────────────────────────────────────────────
class Database {
public:
    SQLHENV  hEnv  = SQL_NULL_HANDLE;
    SQLHDBC  hDbc  = SQL_NULL_HANDLE;
    SQLHSTMT hStmt = SQL_NULL_HANDLE;

    bool connect(const std::string& connStr) {
        SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &hEnv);
        SQLSetEnvAttr(hEnv, SQL_ATTR_ODBC_VERSION, (void*)SQL_OV_ODBC3, 0);
        SQLAllocHandle(SQL_HANDLE_DBC, hEnv, &hDbc);

        SQLCHAR szConnOut[1024];
        SQLSMALLINT cbConnOut;
        SQLRETURN ret = SQLDriverConnectA(
            hDbc, nullptr,
            (SQLCHAR*)connStr.c_str(), SQL_NTS,
            szConnOut, sizeof(szConnOut), &cbConnOut,
            SQL_DRIVER_NOPROMPT
        );
        if (!SQL_SUCCEEDED(ret)) {
            logSqlError(SQL_HANDLE_DBC, hDbc, "SQLDriverConnect");
            return false;
        }
        log("Database connected successfully");
        return true;
    }

    bool execute(const std::string& sql) {
        SQLAllocHandle(SQL_HANDLE_STMT, hDbc, &hStmt);
        SQLRETURN ret = SQLExecDirectA(hStmt, (SQLCHAR*)sql.c_str(), SQL_NTS);
        if (!SQL_SUCCEEDED(ret)) {
            logSqlError(SQL_HANDLE_STMT, hStmt, "SQLExecDirect: " + sql);
            SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
            hStmt = SQL_NULL_HANDLE;
            return false;
        }
        SQLFreeHandle(SQL_HANDLE_STMT, hStmt);
        hStmt = SQL_NULL_HANDLE;
        return true;
    }

    void ensureSchema() {
        execute(R"(
            IF NOT EXISTS (SELECT * FROM sys.tables WHERE name='BettingEvents')
            CREATE TABLE BettingEvents (
                Id            INT IDENTITY(1,1) PRIMARY KEY,
                EventId       NVARCHAR(64)   NOT NULL,
                SportKey      NVARCHAR(64),
                SportTitle    NVARCHAR(128),
                CommenceTime  NVARCHAR(32),
                HomeTeam      NVARCHAR(128),
                AwayTeam      NVARCHAR(128),
                HomeOdds      FLOAT,
                AwayOdds      FLOAT,
                DrawOdds      FLOAT,
                Bookmaker     NVARCHAR(64),
                FetchDate     DATE NOT NULL,
                CreatedAt     DATETIME DEFAULT GETDATE()
            )
        )");

        execute(R"(
            IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name='UX_BettingEvents_EventDate')
            CREATE UNIQUE INDEX UX_BettingEvents_EventDate
            ON BettingEvents(EventId, FetchDate)
        )");
    }

    bool upsertEvent(const BettingEvent& e) {
        std::ostringstream sql;
        sql << "MERGE BettingEvents AS target "
            << "USING (VALUES ("
            << "'" << escapeSql(e.event_id)     << "',"
            << "'" << escapeSql(e.sport_key)    << "',"
            << "'" << escapeSql(e.sport_title)  << "',"
            << "'" << escapeSql(e.commence_time)<< "',"
            << "'" << escapeSql(e.home_team)    << "',"
            << "'" << escapeSql(e.away_team)    << "',"
            <<        e.home_odds               << ","
            <<        e.away_odds               << ","
            <<        e.draw_odds               << ","
            << "'" << escapeSql(e.bookmaker)    << "',"
            << "'" << escapeSql(e.fetch_date)   << "'"
            << ")) AS source(EventId,SportKey,SportTitle,CommenceTime,HomeTeam,AwayTeam,HomeOdds,AwayOdds,DrawOdds,Bookmaker,FetchDate) "
            << "ON target.EventId = source.EventId AND target.FetchDate = source.FetchDate "
            << "WHEN MATCHED THEN UPDATE SET "
            << "  SportTitle=source.SportTitle,CommenceTime=source.CommenceTime,"
            << "  HomeTeam=source.HomeTeam,AwayTeam=source.AwayTeam,"
            << "  HomeOdds=source.HomeOdds,AwayOdds=source.AwayOdds,DrawOdds=source.DrawOdds,"
            << "  Bookmaker=source.Bookmaker "
            << "WHEN NOT MATCHED THEN INSERT "
            << "(EventId,SportKey,SportTitle,CommenceTime,HomeTeam,AwayTeam,HomeOdds,AwayOdds,DrawOdds,Bookmaker,FetchDate) "
            << "VALUES (source.EventId,source.SportKey,source.SportTitle,source.CommenceTime,"
            << "source.HomeTeam,source.AwayTeam,source.HomeOdds,source.AwayOdds,source.DrawOdds,source.Bookmaker,source.FetchDate);";
        return execute(sql.str());
    }

    void disconnect() {
        if (hDbc != SQL_NULL_HANDLE) {
            SQLDisconnect(hDbc);
            SQLFreeHandle(SQL_HANDLE_DBC, hDbc);
        }
        if (hEnv != SQL_NULL_HANDLE)
            SQLFreeHandle(SQL_HANDLE_ENV, hEnv);
    }

private:
    std::string escapeSql(const std::string& s) {
        std::string out;
        for (char c : s)
            out += (c == '\'') ? "''" : std::string(1, c);
        return out;
    }

    void logSqlError(SQLSMALLINT type, SQLHANDLE handle, const std::string& ctx) {
        SQLCHAR state[8], msg[512];
        SQLINTEGER native;
        SQLSMALLINT len;
        SQLGetDiagRecA(type, handle, 1, state, &native, msg, sizeof(msg), &len);
        log("SQL ERROR [" + ctx + "]: " + std::string((char*)msg));
    }
};

// ─── Fetch & Parse ────────────────────────────────────────────────────────────
std::string todayDate() {
    time_t now = time(nullptr);
    char buf[16];
    strftime(buf, sizeof(buf), "%Y-%m-%d", localtime(&now));
    return std::string(buf);
}

const std::vector<std::string> SPORT_KEYS = {
    "americanfootball_nfl",
    "basketball_nba",
    "baseball_mlb",
    "icehockey_nhl",
    "soccer_epl",
    "soccer_uefa_champs_league",
    "basketball_ncaab",
    "americanfootball_ncaaf",
    "mma_mixed_martial_arts",
    "tennis_atp_us_open"
};

std::vector<BettingEvent> fetchEventsForSport(const std::string& sportKey, const std::string& today) {
    std::vector<BettingEvent> events;
    std::string url = ODDS_API_BASE + "/sports/" + sportKey +
                      "/odds/?apiKey=" + ODDS_API_KEY +
                      "&regions=us&markets=h2h&oddsFormat=decimal";

    log("Fetching: " + url);
    std::string body = httpGet(url);
    if (body.empty()) return events;

    try {
        auto jArr = json::parse(body);
        if (!jArr.is_array()) {
            log("WARN: Unexpected response for " + sportKey + ": " + body.substr(0, 200));
            return events;
        }

        for (auto& evt : jArr) {
            std::string commence = evt.value("commence_time", "");
            if (commence.substr(0, 10) != today) continue;

            BettingEvent be;
            be.event_id     = evt.value("id", "");
            be.sport_key    = sportKey;
            be.sport_title  = evt.value("sport_title", "");
            be.commence_time= commence;
            be.home_team    = evt.value("home_team", "");
            be.away_team    = evt.value("away_team", "");
            be.fetch_date   = today;

            if (evt.contains("bookmakers") && evt["bookmakers"].is_array() && !evt["bookmakers"].empty()) {
                auto& bm = evt["bookmakers"][0];
                be.bookmaker = bm.value("title", "");
                if (bm.contains("markets") && bm["markets"].is_array()) {
                    for (auto& mkt : bm["markets"]) {
                        if (mkt.value("key","") == "h2h" && mkt.contains("outcomes")) {
                            for (auto& outcome : mkt["outcomes"]) {
                                std::string name = outcome.value("name", "");
                                double price = outcome.value("price", 0.0);
                                if (name == be.home_team)      be.home_odds = price;
                                else if (name == be.away_team) be.away_odds = price;
                                else                           be.draw_odds = price;
                            }
                        }
                    }
                }
            }
            events.push_back(be);
        }
    } catch (const std::exception& ex) {
        log(std::string("ERROR parsing JSON for ") + sportKey + ": " + ex.what());
    }
    return events;
}

double eventScore(const BettingEvent& e) {
    if (e.home_odds <= 0 || e.away_odds <= 0) return 999.0;
    return std::abs(e.home_odds - e.away_odds);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
int main() {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    log("=== SportsBettingFetcher starting ===");

    std::string today = todayDate();
    log("Fetching top betting events for: " + today);

    std::vector<BettingEvent> allEvents;
    for (auto& sport : SPORT_KEYS) {
        auto evts = fetchEventsForSport(sport, today);
        log("  " + sport + ": " + std::to_string(evts.size()) + " events today");
        for (auto& e : evts)
            allEvents.push_back(e);
    }

    std::sort(allEvents.begin(), allEvents.end(), [](const BettingEvent& a, const BettingEvent& b) {
        return eventScore(a) < eventScore(b);
    });

    if (allEvents.size() > 10)
        allEvents.resize(10);

    log("Top " + std::to_string(allEvents.size()) + " events selected");

    Database db;
    if (!db.connect(DB_CONN_STR)) {
        log("FATAL: Cannot connect to database");
        curl_global_cleanup();
        return 1;
    }
    db.ensureSchema();

    int saved = 0;
    for (auto& e : allEvents) {
        if (db.upsertEvent(e)) {
            log("  Saved: " + e.home_team + " vs " + e.away_team + " [" + e.sport_title + "]");
            saved++;
        }
    }

    log("Done. " + std::to_string(saved) + "/" + std::to_string(allEvents.size()) + " events written to DB");
    db.disconnect();
    curl_global_cleanup();
    return 0;
}
