-- ============================================================
-- setup.sql  - Run in SSMS connecting to: localhost\IDOLMSSQL
-- ============================================================

-- 1. Create the database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SportsBetting')
BEGIN
    CREATE DATABASE SportsBetting;
    PRINT 'Database SportsBetting created.';
END
GO

USE SportsBetting;
GO

-- 2. Create the events table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BettingEvents')
BEGIN
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
    );
    PRINT 'Table BettingEvents created.';
END
GO

-- 3. Unique index
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UX_BettingEvents_EventDate')
BEGIN
    CREATE UNIQUE INDEX UX_BettingEvents_EventDate
    ON BettingEvents(EventId, FetchDate);
    PRINT 'Unique index created.';
END
GO

-- 4. View for today's top 10
CREATE OR ALTER VIEW vw_TodayTop10 AS
SELECT TOP 10
    Id, EventId, SportKey, SportTitle,
    CommenceTime, HomeTeam, AwayTeam,
    HomeOdds, AwayOdds, DrawOdds, Bookmaker, FetchDate
FROM BettingEvents
WHERE FetchDate = CAST(GETDATE() AS DATE)
ORDER BY ABS(HomeOdds - AwayOdds) ASC;
GO

PRINT 'Setup complete. Database SportsBetting is ready on localhost\IDOLMSSQL.';
GO
