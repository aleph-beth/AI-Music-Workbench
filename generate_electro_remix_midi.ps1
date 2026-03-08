$ErrorActionPreference = 'Stop'

$TPQ = 480
$TempoBpm = 128
$Measures = 128
$BeatsPerMeasure = 4
$MeasureTicks = $TPQ * $BeatsPerMeasure
$OutputPath = Join-Path 'output' 'remix_electro_techno_sons_longs.mid'

function Add-Bytes($ms, [byte[]]$bytes) {
  $ms.Write($bytes, 0, $bytes.Length)
}

function Get-VLQ([int]$Value) {
  $arr = @([byte]($Value -band 0x7F))
  $Value = $Value -shr 7
  while ($Value -gt 0) {
    $arr += [byte](($Value -band 0x7F) -bor 0x80)
    $Value = $Value -shr 7
  }
  [array]::Reverse($arr)
  return [byte[]]$arr
}

function Get-BE16([int]$n) {
  return [byte[]]@([byte](($n -shr 8) -band 0xFF), [byte]($n -band 0xFF))
}

function Get-BE32([int]$n) {
  return [byte[]]@(
    [byte](($n -shr 24) -band 0xFF),
    [byte](($n -shr 16) -band 0xFF),
    [byte](($n -shr 8) -band 0xFF),
    [byte]($n -band 0xFF)
  )
}

function Clamp-Velocity([int]$Value) {
  if ($Value -lt 24) { return 24 }
  if ($Value -gt 126) { return 126 }
  return [int]$Value
}

function Add-Note($Events, [int]$StartTick, [int]$DurationTicks, [int]$Channel, [int]$Pitch, [int]$Velocity) {
  $DurationTicks = [Math]::Max(20, $DurationTicks)
  $vel = Clamp-Velocity $Velocity
  $on = [byte[]]@([byte](0x90 -bor $Channel), [byte]($Pitch -band 0x7F), [byte]($vel -band 0x7F))
  $off = [byte[]]@([byte](0x80 -bor $Channel), [byte]($Pitch -band 0x7F), 0)
  $Events.Add([pscustomobject]@{ Tick = $StartTick; Order = 1; Data = $on }) | Out-Null
  $Events.Add([pscustomobject]@{ Tick = $StartTick + $DurationTicks; Order = 0; Data = $off }) | Out-Null
}

function Build-Track([string]$TrackName, [int]$Channel, [int]$Program, $PartEvents) {
  $events = New-Object System.Collections.Generic.List[object]
  foreach ($e in $PartEvents) { $events.Add($e) | Out-Null }
  if ($Channel -ne 9) {
    $events.Add([pscustomobject]@{ Tick = 0; Order = 2; Data = [byte[]]@([byte](0xC0 -bor $Channel), [byte]($Program -band 0x7F)) }) | Out-Null
  }

  $body = New-Object System.IO.MemoryStream

  Add-Bytes $body (Get-VLQ 0)
  $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($TrackName)
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x03, [byte]$nameBytes.Length))
  Add-Bytes $body $nameBytes

  $sorted = $events | Sort-Object Tick, Order
  $lastTick = 0
  foreach ($ev in $sorted) {
    $delta = [int]$ev.Tick - $lastTick
    Add-Bytes $body (Get-VLQ $delta)
    Add-Bytes $body $ev.Data
    $lastTick = [int]$ev.Tick
  }

  Add-Bytes $body (Get-VLQ 0)
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x2F, [byte]0x00))

  $bodyBytes = $body.ToArray()
  $track = New-Object System.IO.MemoryStream
  Add-Bytes $track ([System.Text.Encoding]::ASCII.GetBytes('MTrk'))
  Add-Bytes $track (Get-BE32 $bodyBytes.Length)
  Add-Bytes $track $bodyBytes
  return $track.ToArray()
}

function Build-ConductorTrack([int]$TotalTicks) {
  $tempo = [int](60000000 / $TempoBpm)
  $body = New-Object System.IO.MemoryStream

  Add-Bytes $body (Get-VLQ 0)
  $nameBytes = [System.Text.Encoding]::ASCII.GetBytes('Conductor')
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x03, [byte]$nameBytes.Length))
  Add-Bytes $body $nameBytes

  Add-Bytes $body (Get-VLQ 0)
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x58, [byte]0x04, [byte]0x04, [byte]0x02, [byte]0x18, [byte]0x08))

  Add-Bytes $body (Get-VLQ 0)
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x59, [byte]0x02, [byte]0x00, [byte]0x00))

  Add-Bytes $body (Get-VLQ 0)
  Add-Bytes $body ([byte[]]@(
    [byte]0xFF, [byte]0x51, [byte]0x03,
    [byte](($tempo -shr 16) -band 0xFF),
    [byte](($tempo -shr 8) -band 0xFF),
    [byte]($tempo -band 0xFF)
  ))

  Add-Bytes $body (Get-VLQ $TotalTicks)
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x2F, [byte]0x00))

  $bodyBytes = $body.ToArray()
  $track = New-Object System.IO.MemoryStream
  Add-Bytes $track ([System.Text.Encoding]::ASCII.GetBytes('MTrk'))
  Add-Bytes $track (Get-BE32 $bodyBytes.Length)
  Add-Bytes $track $bodyBytes
  return $track.ToArray()
}

function New-EventList {
  return New-Object System.Collections.Generic.List[object]
}

$rng = [System.Random]::new(20260308)

$kick = New-EventList
$hat = New-EventList
$bass = New-EventList
$pad = New-EventList
$lead = New-EventList

$progression = @(
  @{ root = 38; third = 41; fifth = 45; color = 48 },
  @{ root = 34; third = 38; fifth = 41; color = 46 },
  @{ root = 41; third = 45; fifth = 48; color = 52 },
  @{ root = 36; third = 40; fifth = 43; color = 47 }
)

for ($m = 0; $m -lt $Measures; $m++) {
  $barStart = [int]($m * $MeasureTicks)
  $ch = $progression[$m % $progression.Count]
  $section = [int]($m / 16)
  $energy = [Math]::Min(1.0, $section / 5.0)

  for ($b = 0; $b -lt $BeatsPerMeasure; $b++) {
    $tick = $barStart + ($b * $TPQ)
    $kickVel = 95 + [int]($energy * 16) + $rng.Next(-4, 5)
    Add-Note $kick $tick ([int]($TPQ * 0.22)) 9 36 $kickVel

    $hatTick = $tick + [int]($TPQ * 0.5)
    $hatVel = 62 + [int]($energy * 12) + $rng.Next(-5, 6)
    Add-Note $hat $hatTick ([int]($TPQ * 0.1)) 9 42 $hatVel
  }

  $bassLen = [int]($TPQ * 2.0)
  $bassVel = 72 + [int]($energy * 18) + $rng.Next(-3, 4)
  Add-Note $bass $barStart $bassLen 0 ($ch.root + 12) $bassVel
  Add-Note $bass ($barStart + (2 * $TPQ)) $bassLen 0 ($ch.root + 12) ($bassVel - 4)

  if (($m % 2) -eq 0) {
    $padDur = [int]($MeasureTicks * 1.95)
    $padBase = $barStart
    $padVel = 54 + [int]($energy * 22)
    Add-Note $pad $padBase $padDur 1 ($ch.root + 24) $padVel
    Add-Note $pad $padBase $padDur 1 ($ch.third + 24) ($padVel - 2)
    Add-Note $pad $padBase $padDur 1 ($ch.fifth + 24) ($padVel - 1)
    Add-Note $pad $padBase $padDur 1 ($ch.color + 24) ($padVel - 5)
  }

  if ($m -ge 16) {
    $leadPattern = @(
      ($ch.root + 36),
      ($ch.fifth + 36),
      ($ch.color + 36),
      ($ch.third + 36)
    )
    $leadNote = [int]$leadPattern[$m % $leadPattern.Count]
    $isBreak = (($m % 32) -ge 24 -and ($m % 32) -le 27)
    if (-not $isBreak) {
      $leadDur = if (($m % 4) -eq 0) { [int]($MeasureTicks * 1.85) } else { [int]($MeasureTicks * 0.95) }
      $leadVel = 58 + [int]($energy * 26) + $rng.Next(-2, 3)
      Add-Note $lead $barStart $leadDur 2 $leadNote $leadVel
    }
  }
}

$totalTicks = [int]($Measures * $MeasureTicks)

$tracks = @(
  (Build-ConductorTrack $totalTicks),
  (Build-Track 'Kick' 9 0 $kick),
  (Build-Track 'HiHat' 9 0 $hat),
  (Build-Track 'Bass Synth' 0 38 $bass),
  (Build-Track 'Atmos Pad' 1 88 $pad),
  (Build-Track 'Long Lead' 2 81 $lead)
)

$header = New-Object System.IO.MemoryStream
Add-Bytes $header ([System.Text.Encoding]::ASCII.GetBytes('MThd'))
Add-Bytes $header (Get-BE32 6)
Add-Bytes $header (Get-BE16 1)
Add-Bytes $header (Get-BE16 $tracks.Count)
Add-Bytes $header (Get-BE16 $TPQ)

$outMs = New-Object System.IO.MemoryStream
Add-Bytes $outMs $header.ToArray()
foreach ($trk in $tracks) {
  Add-Bytes $outMs $trk
}

$outDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}
$absOutput = Join-Path (Resolve-Path '.').Path $OutputPath
[System.IO.File]::WriteAllBytes($absOutput, $outMs.ToArray())

$durationSeconds = ($Measures * $BeatsPerMeasure) * (60.0 / $TempoBpm)
Write-Output "Wrote: $OutputPath"
Write-Output ("Estimated duration: {0:N1} seconds ({1:N2} minutes)" -f $durationSeconds, ($durationSeconds / 60.0))
Write-Output "Style: electronic remix / techno, with sustained pads and long lead notes"
Write-Output "Absolute path: $absOutput"