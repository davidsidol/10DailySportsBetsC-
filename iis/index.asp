<%
' ============================================================
' index.asp  - Sports Betting Dashboard
' Uses ODBC DSN-less connection (same driver as the C++ app)
' ============================================================
Option Explicit

Const CONN_STR = "Driver={ODBC Driver 17 for SQL Server};Server=localhost\IDOLMSSQL;Database=SportsBetting;Trusted_Connection=yes;"

Dim conn, rs, errMsg
errMsg = ""

Set conn = Server.CreateObject("ADODB.Connection")
On Error Resume Next
conn.Open CONN_STR
If Err.Number <> 0 Then
    errMsg = "Database connection failed: " & Err.Description
    Err.Clear
End If
On Error GoTo 0

Dim eventList()
Dim eventCount : eventCount = 0

If errMsg = "" Then
    Set rs = Server.CreateObject("ADODB.Recordset")
    On Error Resume Next
    rs.Open "SELECT TOP 10 SportTitle, HomeTeam, AwayTeam, HomeOdds, AwayOdds, DrawOdds, " & _
            "Bookmaker, CommenceTime, FetchDate " & _
            "FROM BettingEvents " & _
            "WHERE FetchDate = CAST(GETDATE() AS DATE) " & _
            "ORDER BY ABS(HomeOdds - AwayOdds) ASC", conn
    If Err.Number <> 0 Then
        errMsg = "Query failed: " & Err.Description
        Err.Clear
    End If
    On Error GoTo 0

    If errMsg = "" Then
        Do While Not rs.EOF
            eventCount = eventCount + 1
            ReDim Preserve eventList(eventCount - 1)
            Dim ev
            Set ev = Server.CreateObject("Scripting.Dictionary")
            ev.Add "sport",    rs("SportTitle") & ""
            ev.Add "home",     rs("HomeTeam") & ""
            ev.Add "away",     rs("AwayTeam") & ""
            ev.Add "homeOdds", rs("HomeOdds") & ""
            ev.Add "awayOdds", rs("AwayOdds") & ""
            ev.Add "drawOdds", rs("DrawOdds") & ""
            ev.Add "bookie",   rs("Bookmaker") & ""
            ev.Add "time",     rs("CommenceTime") & ""
            Set eventList(eventCount - 1) = ev
            rs.MoveNext
        Loop
        rs.Close
    End If
    conn.Close
End If

Function FmtTime(t)
    If t = "" Or IsNull(t) Or IsEmpty(t) Then
        FmtTime = "TBD"
        Exit Function
    End If
    Dim d
    On Error Resume Next
    d = CDate(Replace(Replace(t, "T", " "), "Z", ""))
    If Err.Number <> 0 Then
        FmtTime = t
        Err.Clear
    Else
        FmtTime = FormatDateTime(d, 4) & " UTC"
    End If
    On Error GoTo 0
End Function

Function FmtOdds(o)
    If o = "" Or o = "0" Or IsNull(o) Then
        FmtOdds = "&mdash;"
    Else
        FmtOdds = FormatNumber(CDbl(o), 2)
    End If
End Function

Dim today
today = FormatDateTime(Now(), 2)
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="3600">
<title>Top 10 Betting Events &ndash; <%= today %></title>
<style>
  :root {
    --bg:      #0d1117;
    --surface: #161b22;
    --card:    #1c2230;
    --border:  #30363d;
    --accent:  #00d4aa;
    --gold:    #f4c542;
    --red:     #e05c5c;
    --text:    #e6edf3;
    --muted:   #8b949e;
    --radius:  12px;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Segoe UI', system-ui, sans-serif;
    min-height: 100vh;
    padding: 24px 16px 48px;
  }
  header { text-align: center; padding: 32px 0 40px; }
  header h1 { font-size: 2rem; font-weight: 700; color: var(--accent); }
  header p { color: var(--muted); margin-top: 6px; font-size: .95rem; }
  .badge {
    display: inline-block; background: var(--accent); color: #000;
    font-size: .7rem; font-weight: 700; text-transform: uppercase;
    letter-spacing: 1px; padding: 2px 8px; border-radius: 20px; margin-left: 8px;
  }
  .container { max-width: 1100px; margin: 0 auto; }
  .event-card {
    background: var(--card); border: 1px solid var(--border);
    border-radius: var(--radius); padding: 20px 24px; margin-bottom: 16px;
    display: grid; grid-template-columns: 36px 1fr auto;
    gap: 16px; align-items: center; transition: border-color .2s;
  }
  .event-card:hover { border-color: var(--accent); }
  .rank-num { font-size: 1.5rem; font-weight: 800; color: var(--gold); text-align: center; }
  .rank-num.top3 { color: var(--accent); }
  .matchup { font-size: 1.1rem; font-weight: 600; margin-bottom: 4px; }
  .vs { color: var(--muted); font-weight: 400; margin: 0 6px; font-size: .9rem; }
  .meta { font-size: .8rem; color: var(--muted); display: flex; gap: 16px; flex-wrap: wrap; margin-top: 4px; }
  .odds-block { display: flex; gap: 8px; align-items: center; }
  .odds-pill {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; padding: 8px 14px; text-align: center; min-width: 72px;
  }
  .odds-pill .label { font-size: .65rem; color: var(--muted); text-transform: uppercase; letter-spacing: .8px; margin-bottom: 2px; }
  .odds-pill .val { font-size: 1rem; font-weight: 700; color: var(--accent); }
  .odds-pill .val.draw { color: var(--gold); }
  .error-box {
    background: #2d1a1a; border: 1px solid var(--red); border-radius: var(--radius);
    padding: 20px 24px; color: var(--red); text-align: center; margin: 40px auto; max-width: 700px;
  }
  .empty-box { text-align: center; color: var(--muted); padding: 60px 20px; }
  .empty-box h2 { margin-bottom: 12px; color: var(--text); }
  footer { text-align: center; color: var(--muted); font-size: .8rem; margin-top: 48px; }
  @media (max-width: 640px) {
    .event-card { grid-template-columns: 28px 1fr; }
    .odds-block { grid-column: 1 / -1; }
  }
</style>
</head>
<body>
<header>
  <h1>&#127942; Top 10 Betting Events <span class="badge">Live</span></h1>
  <p><%= today %> &nbsp;&middot;&nbsp; Auto-refreshes hourly &nbsp;&middot;&nbsp; Data via The Odds API</p>
</header>
<div class="container">
<% If errMsg <> "" Then %>
  <div class="error-box">
    <strong>&#9888; Error loading data</strong><br><%= Server.HTMLEncode(errMsg) %>
  </div>
<% ElseIf eventCount = 0 Then %>
  <div class="empty-box">
    <h2>No events found for today</h2>
    <p>The fetcher runs daily at 06:00 AM.<br>Run <code>C:\SportsBettingApp\SportsBettingFetcher.exe</code> manually to populate today's data.</p>
  </div>
<% Else %>
  <% Dim i
  For i = 0 To eventCount - 1
    Dim e : Set e = eventList(i)
    Dim rankClass : rankClass = ""
    If i < 3 Then rankClass = " top3"
  %>
  <div class="event-card">
    <div class="rank-num<%= rankClass %>">#<%= i + 1 %></div>
    <div class="event-body">
      <div class="matchup">
        <%= Server.HTMLEncode(e("home")) %>
        <span class="vs">vs</span>
        <%= Server.HTMLEncode(e("away")) %>
      </div>
      <div class="meta">
        <span>&#127885; <%= Server.HTMLEncode(e("sport")) %></span>
        <span>&#128336; <%= FmtTime(e("time")) %></span>
        <% If e("bookie") <> "" Then %><span>&#128214; <%= Server.HTMLEncode(e("bookie")) %></span><% End If %>
      </div>
    </div>
    <div class="odds-block">
      <div class="odds-pill">
        <div class="label"><%= Left(Server.HTMLEncode(e("home")), 8) %></div>
        <div class="val"><%= FmtOdds(e("homeOdds")) %></div>
      </div>
      <% If e("drawOdds") <> "" And e("drawOdds") <> "0" Then %>
      <div class="odds-pill">
        <div class="label">Draw</div>
        <div class="val draw"><%= FmtOdds(e("drawOdds")) %></div>
      </div>
      <% End If %>
      <div class="odds-pill">
        <div class="label"><%= Left(Server.HTMLEncode(e("away")), 8) %></div>
        <div class="val"><%= FmtOdds(e("awayOdds")) %></div>
      </div>
    </div>
  </div>
  <% Next %>
<% End If %>
</div>
<footer>
  Data sourced from <a href="https://the-odds-api.com" style="color:var(--accent)">The Odds API</a> &nbsp;&middot;&nbsp;
  For informational purposes only &nbsp;&middot;&nbsp; Updated: <%= Now() %>
</footer>
</body>
</html>
