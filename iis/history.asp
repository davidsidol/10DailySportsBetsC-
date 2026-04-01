<%
' ============================================================
' history.asp - Historical Daily Event Rankings Dashboard
' Allows lookup of top 10 betting events for any past date
' ============================================================
Option Explicit

Const CONN_STR = "Driver={ODBC Driver 17 for SQL Server};Server=localhost\IDOLMSSQL;Database=SportsBetting;Trusted_Connection=yes;"

Dim selectedDate
selectedDate = Request.QueryString("date")
If selectedDate = "" Then
    selectedDate = CStr(Year(Now())) & "-" & Right("0" & CStr(Month(Now())), 2) & "-" & Right("0" & CStr(Day(Now())), 2)
End If

Dim isValidDate : isValidDate = True
On Error Resume Next
Dim testDate : testDate = CDate(selectedDate)
If Err.Number <> 0 Then isValidDate = False
Err.Clear
On Error GoTo 0

Dim conn, rs, errMsg
errMsg = ""
Set conn = Server.CreateObject("ADODB.Connection")
On Error Resume Next
conn.Open CONN_STR
If Err.Number <> 0 Then errMsg = "Database connection failed: " & Err.Description : Err.Clear
On Error GoTo 0

Dim availDates()
Dim availCount : availCount = 0
If errMsg = "" Then
    Set rs = Server.CreateObject("ADODB.Recordset")
    On Error Resume Next
    rs.Open "SELECT DISTINCT FetchDate FROM BettingEvents ORDER BY FetchDate DESC", conn
    If Err.Number <> 0 Then errMsg = "Failed to load dates: " & Err.Description : Err.Clear
    Else
        Do While Not rs.EOF
            availCount = availCount + 1
            ReDim Preserve availDates(availCount - 1)
            availDates(availCount - 1) = rs("FetchDate") & ""
            rs.MoveNext
        Loop
        rs.Close
    End If
    On Error GoTo 0
End If

Dim eventList()
Dim eventCount : eventCount = 0
If errMsg = "" And isValidDate Then
    Set rs = Server.CreateObject("ADODB.Recordset")
    On Error Resume Next
    rs.Open "SELECT TOP 10 SportTitle, HomeTeam, AwayTeam, HomeOdds, AwayOdds, DrawOdds, Bookmaker, CommenceTime, FetchDate FROM BettingEvents WHERE FetchDate = '" & selectedDate & "' ORDER BY ABS(HomeOdds - AwayOdds) ASC", conn
    If Err.Number <> 0 Then errMsg = "Query failed: " & Err.Description : Err.Clear
    Else
        Do While Not rs.EOF
            eventCount = eventCount + 1
            ReDim Preserve eventList(eventCount - 1)
            Dim ev : Set ev = Server.CreateObject("Scripting.Dictionary")
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
    On Error GoTo 0
End If

Dim statSports : statSports = ""
If errMsg = "" And eventCount > 0 Then
    Dim rsStat : Set rsStat = Server.CreateObject("ADODB.Recordset")
    On Error Resume Next
    rsStat.Open "SELECT SportTitle, COUNT(*) AS Cnt FROM BettingEvents WHERE FetchDate = '" & selectedDate & "' GROUP BY SportTitle ORDER BY Cnt DESC", conn
    If Err.Number = 0 Then
        Dim sp : sp = ""
        Do While Not rsStat.EOF
            If sp <> "" Then sp = sp & ", "
            sp = sp & rsStat("SportTitle") & " (" & rsStat("Cnt") & ")"
            rsStat.MoveNext
        Loop
        statSports = sp
        rsStat.Close
    End If
    Err.Clear : On Error GoTo 0
End If

If errMsg = "" Then conn.Close

Function FmtTime(t)
    If t = "" Or IsNull(t) Or IsEmpty(t) Then FmtTime = "TBD" : Exit Function
    Dim d
    On Error Resume Next
    d = CDate(Replace(Replace(t, "T", " "), "Z", ""))
    If Err.Number <> 0 Then FmtTime = t : Err.Clear
    Else FmtTime = FormatDateTime(d, 4) & " UTC"
    End If
    On Error GoTo 0
End Function

Function FmtOdds(o)
    If o = "" Or o = "0" Or IsNull(o) Then FmtOdds = "&mdash;"
    Else FmtOdds = FormatNumber(CDbl(o), 2)
    End If
End Function

Function FmtDisplayDate(d)
    On Error Resume Next
    Dim dt : dt = CDate(d)
    If Err.Number <> 0 Then FmtDisplayDate = d : Err.Clear
    Else FmtDisplayDate = FormatDateTime(dt, 1)
    End If
    On Error GoTo 0
End Function

Dim today : today = FormatDateTime(Now(), 2)
Dim prevDate, nextDate, curDt
On Error Resume Next
curDt = CDate(selectedDate)
If Err.Number = 0 Then
    prevDate = CStr(Year(curDt-1)) & "-" & Right("0" & CStr(Month(curDt-1)),2) & "-" & Right("0" & CStr(Day(curDt-1)),2)
    nextDate = CStr(Year(curDt+1)) & "-" & Right("0" & CStr(Month(curDt+1)),2) & "-" & Right("0" & CStr(Day(curDt+1)),2)
Else
    prevDate = selectedDate : nextDate = selectedDate : Err.Clear
End If
On Error GoTo 0
%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Historical Betting Rankings</title>
<style>
  :root{--bg:#0d1117;--surface:#161b22;--card:#1c2230;--border:#30363d;--accent:#00d4aa;--gold:#f4c542;--red:#e05c5c;--text:#e6edf3;--muted:#8b949e;--radius:12px;}
  *{box-sizing:border-box;margin:0;padding:0;}
  body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;min-height:100vh;padding:24px 16px 48px;}
  header{text-align:center;padding:32px 0 32px;}
  header h1{font-size:2rem;font-weight:700;color:var(--accent);}
  header p{color:var(--muted);margin-top:6px;font-size:.95rem;}
  .nav{display:flex;justify-content:center;gap:12px;margin-bottom:32px;flex-wrap:wrap;}
  .nav a{background:var(--surface);border:1px solid var(--border);color:var(--text);text-decoration:none;padding:8px 20px;border-radius:8px;font-size:.9rem;}
  .nav a:hover,.nav a.active{border-color:var(--accent);color:var(--accent);}
  .nav a.active{background:#0d2e28;}
  .container{max-width:1100px;margin:0 auto;}
  .picker-panel{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);padding:24px 28px;margin-bottom:28px;display:flex;align-items:center;gap:20px;flex-wrap:wrap;}
  .picker-panel label{color:var(--muted);font-size:.9rem;white-space:nowrap;}
  .picker-panel input[type=date]{background:var(--surface);border:1px solid var(--border);color:var(--text);padding:10px 14px;border-radius:8px;font-size:1rem;outline:none;}
  .picker-panel select{background:var(--surface);border:1px solid var(--border);color:var(--text);padding:10px 14px;border-radius:8px;font-size:.9rem;outline:none;max-width:220px;}
  .btn{background:var(--accent);color:#000;border:none;padding:10px 24px;border-radius:8px;font-size:.95rem;font-weight:700;cursor:pointer;}
  .stats-bar{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:16px 24px;margin-bottom:24px;display:flex;gap:32px;flex-wrap:wrap;align-items:center;}
  .stat-item{display:flex;flex-direction:column;gap:2px;}
  .stat-label{font-size:.7rem;color:var(--muted);text-transform:uppercase;letter-spacing:1px;}
  .stat-value{font-size:1.1rem;font-weight:700;color:var(--accent);}
  .stat-value.gold{color:var(--gold);}
  .date-heading{display:flex;align-items:center;gap:16px;margin-bottom:20px;flex-wrap:wrap;}
  .date-heading h2{font-size:1.3rem;font-weight:700;}
  .date-nav{display:flex;gap:8px;}
  .date-nav a{background:var(--surface);border:1px solid var(--border);color:var(--muted);padding:6px 14px;border-radius:6px;text-decoration:none;font-size:.85rem;}
  .date-nav a:hover{border-color:var(--accent);color:var(--accent);}
  .event-card{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);padding:18px 22px;margin-bottom:14px;display:grid;grid-template-columns:36px 1fr auto;gap:16px;align-items:center;}
  .event-card:hover{border-color:var(--accent);}
  .rank-num{font-size:1.4rem;font-weight:800;color:var(--gold);text-align:center;}
  .rank-num.top3{color:var(--accent);}
  .matchup{font-size:1.05rem;font-weight:600;margin-bottom:4px;}
  .vs{color:var(--muted);font-weight:400;margin:0 6px;font-size:.85rem;}
  .meta{font-size:.78rem;color:var(--muted);display:flex;gap:14px;flex-wrap:wrap;margin-top:4px;}
  .odds-block{display:flex;gap:8px;align-items:center;}
  .odds-pill{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:7px 12px;text-align:center;min-width:68px;}
  .odds-pill .label{font-size:.6rem;color:var(--muted);text-transform:uppercase;letter-spacing:.8px;margin-bottom:2px;}
  .odds-pill .val{font-size:.95rem;font-weight:700;color:var(--accent);}
  .odds-pill .val.draw{color:var(--gold);}
  .avail-section{margin-top:36px;}
  .avail-section h3{font-size:.85rem;color:var(--muted);text-transform:uppercase;letter-spacing:1px;margin-bottom:14px;}
  .date-chips{display:flex;flex-wrap:wrap;gap:8px;}
  .date-chip{background:var(--surface);border:1px solid var(--border);color:var(--muted);padding:6px 14px;border-radius:20px;text-decoration:none;font-size:.8rem;}
  .date-chip:hover{border-color:var(--accent);color:var(--accent);}
  .date-chip.selected{background:#0d2e28;border-color:var(--accent);color:var(--accent);font-weight:700;}
  .error-box{background:#2d1a1a;border:1px solid var(--red);border-radius:var(--radius);padding:20px 24px;color:var(--red);text-align:center;margin:40px auto;max-width:700px;}
  .empty-box{text-align:center;color:var(--muted);padding:60px 20px;}
  .empty-box h2{margin-bottom:12px;color:var(--text);}
  footer{text-align:center;color:var(--muted);font-size:.8rem;margin-top:48px;}
  @media(max-width:640px){.event-card{grid-template-columns:28px 1fr;}.odds-block{grid-column:1/-1;}.picker-panel{flex-direction:column;}}
</style>
</head>
<body>
<header>
  <h1>&#128197; Historical Betting Rankings</h1>
  <p>Look up the top 10 most competitive betting events for any past date</p>
</header>
<div class="nav">
  <a href="index.asp">&#128306; Today's Events</a>
  <a href="history.asp" class="active">&#128197; Historical Lookup</a>
</div>
<div class="container">
  <div class="picker-panel">
    <label>&#128197; Select Date:</label>
    <form method="GET" action="history.asp" style="display:flex;gap:10px;align-items:center;flex-wrap:wrap">
      <input type="date" name="date" value="<%= selectedDate %>" max="<%= today %>">
      <button type="submit" class="btn">View Rankings</button>
    </form>
    <% If availCount > 0 Then %>
    <form method="GET" action="history.asp" style="display:flex;gap:10px;align-items:center">
      <label style="font-size:.8rem">or jump to:</label>
      <select name="date" onchange="this.form.submit()">
        <% Dim di
        For di = 0 To availCount - 1
          Dim selAttr : selAttr = ""
          If availDates(di) = selectedDate Then selAttr = " selected"
        %>
        <option value="<%= availDates(di) %>"<%= selAttr %>><%= FmtDisplayDate(availDates(di)) %></option>
        <% Next %>
      </select>
    </form>
    <% End If %>
  </div>

  <% If errMsg <> "" Then %>
    <div class="error-box"><strong>&#9888; Error</strong><br><%= Server.HTMLEncode(errMsg) %></div>
  <% ElseIf Not isValidDate Then %>
    <div class="empty-box"><h2>Invalid date</h2><p>Please select a valid date above.</p></div>
  <% Else %>
    <div class="date-heading">
      <h2>&#127942; <%= FmtDisplayDate(selectedDate) %></h2>
      <div class="date-nav">
        <a href="history.asp?date=<%= prevDate %>">&larr; Prev Day</a>
        <a href="history.asp?date=<%= today %>">Today</a>
        <% If selectedDate < today Then %><a href="history.asp?date=<%= nextDate %>">Next Day &rarr;</a><% End If %>
      </div>
    </div>

    <% If eventCount > 0 Then %>
    <div class="stats-bar">
      <div class="stat-item"><span class="stat-label">Events Tracked</span><span class="stat-value"><%= eventCount %></span></div>
      <div class="stat-item"><span class="stat-label">Date</span><span class="stat-value gold"><%= selectedDate %></span></div>
      <% If statSports <> "" Then %><div class="stat-item"><span class="stat-label">Sports</span><span class="stat-value" style="font-size:.85rem;color:var(--text)"><%= Server.HTMLEncode(statSports) %></span></div><% End If %>
    </div>
    <% Dim i
    For i = 0 To eventCount - 1
      Dim e : Set e = eventList(i)
      Dim rankClass : rankClass = "rank-num"
      If i < 3 Then rankClass = "rank-num top3"
    %>
    <div class="event-card">
      <div class="<%= rankClass %>">#<%= i+1 %></div>
      <div class="event-body">
        <div class="matchup"><%= Server.HTMLEncode(e("home")) %><span class="vs">vs</span><%= Server.HTMLEncode(e("away")) %></div>
        <div class="meta">
          <span>&#127885; <%= Server.HTMLEncode(e("sport")) %></span>
          <span>&#128336; <%= FmtTime(e("time")) %></span>
          <% If e("bookie") <> "" Then %><span>&#128214; <%= Server.HTMLEncode(e("bookie")) %></span><% End If %>
        </div>
      </div>
      <div class="odds-block">
        <div class="odds-pill"><div class="label"><%= Left(Server.HTMLEncode(e("home")),8) %></div><div class="val"><%= FmtOdds(e("homeOdds")) %></div></div>
        <% If e("drawOdds") <> "" And e("drawOdds") <> "0" Then %>
        <div class="odds-pill"><div class="label">Draw</div><div class="val draw"><%= FmtOdds(e("drawOdds")) %></div></div>
        <% End If %>
        <div class="odds-pill"><div class="label"><%= Left(Server.HTMLEncode(e("away")),8) %></div><div class="val"><%= FmtOdds(e("awayOdds")) %></div></div>
      </div>
    </div>
    <% Next %>
    <% Else %>
    <div class="empty-box"><h2>No data for <%= FmtDisplayDate(selectedDate) %></h2><p>The fetcher hasn't run for this date.</p></div>
    <% End If %>

    <% If availCount > 0 Then %>
    <div class="avail-section">
      <h3>&#128196; All Available Dates (<%= availCount %> days tracked)</h3>
      <div class="date-chips">
        <% Dim ci
        For ci = 0 To availCount - 1
          Dim chipClass : chipClass = "date-chip"
          If availDates(ci) = selectedDate Then chipClass = "date-chip selected"
        %>
        <a href="history.asp?date=<%= availDates(ci) %>" class="<%= chipClass %>"><%= availDates(ci) %></a>
        <% Next %>
      </div>
    </div>
    <% End If %>
  <% End If %>
</div>
<footer>
  Data sourced from <a href="https://the-odds-api.com" style="color:var(--accent)">The Odds API</a> &nbsp;&middot;&nbsp;
  For informational purposes only &nbsp;&middot;&nbsp; Generated: <%= Now() %>
</footer>
</body>
</html>
