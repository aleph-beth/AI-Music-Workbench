$ErrorActionPreference = 'Stop'

$TPQ = 480
$TempoBpm = 96
$Measures = 128
$BeatsPerMeasure = 4
$MeasureTicks = $TPQ * $BeatsPerMeasure
$OutputPath = Join-Path 'output' 'quatuor_classique_plus_4min_dynamique.mid'

$PC = @{
  'C' = 0; 'C#' = 1; 'Db' = 1; 'D' = 2; 'D#' = 3; 'Eb' = 3;
  'E' = 4; 'F' = 5; 'F#' = 6; 'Gb' = 6; 'G' = 7; 'G#' = 8;
  'Ab' = 8; 'A' = 9; 'A#' = 10; 'Bb' = 10; 'B' = 11
}

function Get-MidiNote([string]$Name, [int]$Octave) {
  return [int](12 * ($Octave + 1) + $PC[$Name])
}

function Clamp-Velocity([int]$Value) {
  if ($Value -lt 28) { return 28 }
  if ($Value -gt 126) { return 126 }
  return [int]$Value
}

function Get-BarDynamic([int]$Measure) {
  $section = [int]($Measure / 32)
  $inSection = $Measure % 32
  $phrasePos = $Measure % 8

  switch ($section) {
    0 { $start = 58; $ending = 76 }
    1 { $start = 66; $ending = 88 }
    2 { $start = 74; $ending = 98 }
    default { $start = 82; $ending = 108 }
  }

  $progress = if ($inSection -eq 0) { 0.0 } else { $inSection / 31.0 }
  $longCurve = $start + (($ending - $start) * $progress)
  $phraseShape = @(0, 2, 5, 7, 6, 4, 2, 0)[$phrasePos]
  $swell = [Math]::Sin((($Measure % 16) / 16.0) * [Math]::PI) * 5.5

  return [int][Math]::Round($longCurve + $phraseShape + $swell)
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

function Add-Note($Events, [int]$StartTick, [int]$DurationTicks, [int]$Channel, [int]$Pitch, [int]$Velocity) {
  $DurationTicks = [Math]::Max(30, $DurationTicks)
  $clampedVel = Clamp-Velocity $Velocity
  $on = [byte[]]@([byte](0x90 -bor $Channel), [byte]($Pitch -band 0x7F), [byte]($clampedVel -band 0x7F))
  $off = [byte[]]@([byte](0x80 -bor $Channel), [byte]($Pitch -band 0x7F), 0)
  $Events.Add([pscustomobject]@{ Tick = $StartTick; Order = 1; Data = $on }) | Out-Null
  $Events.Add([pscustomobject]@{ Tick = $StartTick + $DurationTicks; Order = 0; Data = $off }) | Out-Null
}

function Get-Triad([int]$RootPc, [string]$Quality) {
  switch ($Quality) {
    'min' { return @([int]$RootPc, [int](($RootPc + 3) % 12), [int](($RootPc + 7) % 12)) }
    'maj' { return @([int]$RootPc, [int](($RootPc + 4) % 12), [int](($RootPc + 7) % 12)) }
    'dim' { return @([int]$RootPc, [int](($RootPc + 3) % 12), [int](($RootPc + 6) % 12)) }
    default { throw "Unknown quality: $Quality" }
  }
}

function Get-ChordProgression {
  $phraseA = @(
    [pscustomobject]@{ Root='D'; Qual='min' }, [pscustomobject]@{ Root='G'; Qual='min' },
    [pscustomobject]@{ Root='A'; Qual='maj' }, [pscustomobject]@{ Root='D'; Qual='min' },
    [pscustomobject]@{ Root='Bb'; Qual='maj' }, [pscustomobject]@{ Root='G'; Qual='min' },
    [pscustomobject]@{ Root='A'; Qual='maj' }, [pscustomobject]@{ Root='D'; Qual='min' }
  )
  $phraseB = @(
    [pscustomobject]@{ Root='F'; Qual='maj' }, [pscustomobject]@{ Root='C'; Qual='maj' },
    [pscustomobject]@{ Root='G'; Qual='min' }, [pscustomobject]@{ Root='A'; Qual='maj' },
    [pscustomobject]@{ Root='D'; Qual='min' }, [pscustomobject]@{ Root='Bb'; Qual='maj' },
    [pscustomobject]@{ Root='A'; Qual='maj' }, [pscustomobject]@{ Root='D'; Qual='min' }
  )
  $phraseDev = @(
    [pscustomobject]@{ Root='G'; Qual='min' }, [pscustomobject]@{ Root='C'; Qual='maj' },
    [pscustomobject]@{ Root='F'; Qual='maj' }, [pscustomobject]@{ Root='Bb'; Qual='maj' },
    [pscustomobject]@{ Root='E'; Qual='dim' }, [pscustomobject]@{ Root='A'; Qual='maj' },
    [pscustomobject]@{ Root='D'; Qual='min' }, [pscustomobject]@{ Root='A'; Qual='maj' }
  )
  $phraseCoda = @(
    [pscustomobject]@{ Root='D'; Qual='min' }, [pscustomobject]@{ Root='G'; Qual='min' },
    [pscustomobject]@{ Root='A'; Qual='maj' }, [pscustomobject]@{ Root='D'; Qual='min' },
    [pscustomobject]@{ Root='Bb'; Qual='maj' }, [pscustomobject]@{ Root='A'; Qual='maj' },
    [pscustomobject]@{ Root='D'; Qual='maj' }, [pscustomobject]@{ Root='D'; Qual='maj' }
  )

  $progression = New-Object System.Collections.Generic.List[object]
  for ($m = 0; $m -lt $Measures; $m++) {
    if ($m -lt 32) {
      $progression.Add($phraseA[$m % $phraseA.Count]) | Out-Null
    } elseif ($m -lt 64) {
      $progression.Add($phraseB[$m % $phraseB.Count]) | Out-Null
    } elseif ($m -lt 96) {
      $progression.Add($phraseDev[$m % $phraseDev.Count]) | Out-Null
    } else {
      $progression.Add($phraseCoda[$m % $phraseCoda.Count]) | Out-Null
    }
  }
  return $progression
}

function Get-RegisterPitches($ChordPcs, [int]$Low, [int]$High) {
  $out = New-Object System.Collections.Generic.List[int]
  for ($p = $Low; $p -le $High; $p++) {
    if ($ChordPcs -contains ($p % 12)) {
      $out.Add([int]$p) | Out-Null
    }
  }
  return $out
}

function Choose-Stepwise($Rng, [Nullable[int]]$CurrentPitch, $AllowedPitches) {
  $arr = @($AllowedPitches | Sort-Object)
  if ($arr.Count -eq 0) { return 60 }
  if (-not $CurrentPitch.HasValue) {
    return [int]$arr[$Rng.Next(0, $arr.Count)]
  }

  $bestIdx = 0
  $bestDist = [Math]::Abs($arr[0] - $CurrentPitch.Value)
  for ($i = 1; $i -lt $arr.Count; $i++) {
    $d = [Math]::Abs($arr[$i] - $CurrentPitch.Value)
    if ($d -lt $bestDist) {
      $bestDist = $d
      $bestIdx = $i
    }
  }

  $candidates = New-Object System.Collections.Generic.List[int]
  $candidates.Add([int]$arr[$bestIdx]) | Out-Null
  if ($bestIdx -gt 0) { $candidates.Add([int]$arr[$bestIdx - 1]) | Out-Null }
  if ($bestIdx -lt $arr.Count - 1) { $candidates.Add([int]$arr[$bestIdx + 1]) | Out-Null }

  if ($Rng.NextDouble() -lt 0.15) {
    return [int]$arr[$Rng.Next(0, $arr.Count)]
  }
  return [int]$candidates[$Rng.Next(0, $candidates.Count)]
}

function Generate-Parts {
  $rng = [System.Random]::new(147)
  $progression = Get-ChordProgression

  $parts = @{
    v1 = New-Object System.Collections.Generic.List[object]
    v2 = New-Object System.Collections.Generic.List[object]
    va = New-Object System.Collections.Generic.List[object]
    vc = New-Object System.Collections.Generic.List[object]
  }

  [Nullable[int]]$currentV1 = $null
  [Nullable[int]]$currentV2 = $null
  [Nullable[int]]$currentVa = $null
  [Nullable[int]]$currentVc = $null

  $rhythmV1A = @(1.0, 0.5, 0.5, 1.0, 1.0)
  $rhythmV1B = @(0.5, 0.5, 1.0, 0.5, 0.5, 1.0)
  $rhythmV2 = @(1.0, 1.0, 1.0, 1.0)
  $rhythmVa = @(0.5, 0.5, 0.5, 0.5, 1.0, 1.0)
  $rhythmVc = @(2.0, 2.0)

  for ($m = 0; $m -lt $progression.Count; $m++) {
    $rootName = [string]$progression[$m].Root
    $quality = [string]$progression[$m].Qual
    $rootPc = [int]$PC[$rootName]
    $chordPcs = Get-Triad $rootPc $quality
    $barStart = [int]($m * $MeasureTicks)
    $barDyn = Get-BarDynamic $m

    $regV1 = Get-RegisterPitches $chordPcs (Get-MidiNote 'A' 4) (Get-MidiNote 'E' 6)
    $regV2 = Get-RegisterPitches $chordPcs (Get-MidiNote 'D' 4) (Get-MidiNote 'B' 5)
    $regVa = Get-RegisterPitches $chordPcs (Get-MidiNote 'A' 3) (Get-MidiNote 'F' 5)
    $regVc = Get-RegisterPitches $chordPcs (Get-MidiNote 'D' 2) (Get-MidiNote 'C' 4)

    if (([int]($m / 8) % 2) -eq 0) {
      $patV1 = $rhythmV1A
      $accV1 = @(10, 3, 7, 6, 4)
    } else {
      $patV1 = $rhythmV1B
      $accV1 = @(9, 5, 7, 4, 6, 3)
    }

    $t = $barStart
    for ($i = 0; $i -lt $patV1.Count; $i++) {
      $beats = $patV1[$i]
      $pitch = Choose-Stepwise $rng $currentV1 $regV1
      $currentV1 = [Nullable[int]]$pitch
      $human = $rng.Next(-4, 5)
      $vel = Clamp-Velocity ($barDyn + 8 + $accV1[$i] + $human)
      Add-Note $parts.v1 $t ([int]($beats * $TPQ * 0.95)) 0 $pitch $vel
      $t += [int]($beats * $TPQ)
    }

    $t = $barStart
    $accV2 = @(8, 3, 6, 2)
    for ($i = 0; $i -lt $rhythmV2.Count; $i++) {
      $beats = $rhythmV2[$i]
      $anchor = [int]$regV2[($i + $m) % $regV2.Count]
      if ($rng.NextDouble() -lt 0.35) {
        $pitch = Choose-Stepwise $rng $currentV2 $regV2
      } else {
        $pitch = $anchor
      }
      $currentV2 = [Nullable[int]]$pitch
      $human = $rng.Next(-3, 4)
      $vel = Clamp-Velocity ($barDyn + 3 + $accV2[$i] + $human)
      Add-Note $parts.v2 $t ([int]($beats * $TPQ * 0.92)) 1 $pitch $vel
      $t += [int]($beats * $TPQ)
    }

    $t = $barStart
    $accVa = @(6, 4, 5, 3, 7, 5)
    for ($i = 0; $i -lt $rhythmVa.Count; $i++) {
      $beats = $rhythmVa[$i]
      if (($i % 2) -eq 0) {
        $pitch = [int]$regVa[($m + $i) % $regVa.Count]
      } else {
        $pitch = Choose-Stepwise $rng $currentVa $regVa
      }
      $currentVa = [Nullable[int]]$pitch
      $human = $rng.Next(-3, 4)
      $vel = Clamp-Velocity ($barDyn - 2 + $accVa[$i] + $human)
      Add-Note $parts.va $t ([int]($beats * $TPQ * 0.88)) 2 $pitch $vel
      $t += [int]($beats * $TPQ)
    }

    $t = $barStart
    $accVc = @(12, 7)
    for ($i = 0; $i -lt $rhythmVc.Count; $i++) {
      $beats = $rhythmVc[$i]
      if ($i -eq 0) {
        $rootOptions = @($regVc | Where-Object { ($_ % 12) -eq $rootPc })
        if ($rootOptions.Count -gt 0) {
          $pitch = [int]$rootOptions[0]
        } else {
          $pitch = [int]$regVc[0]
        }
      } else {
        $pitch = [int]$regVc[($m + $i + 1) % $regVc.Count]
      }
      if ($rng.NextDouble() -lt 0.2) {
        $pitch = Choose-Stepwise $rng $currentVc $regVc
      }
      $currentVc = [Nullable[int]]$pitch
      $human = $rng.Next(-2, 3)
      $vel = Clamp-Velocity ($barDyn + 5 + $accVc[$i] + $human)
      Add-Note $parts.vc $t ([int]($beats * $TPQ * 0.97)) 3 $pitch $vel
      $t += [int]($beats * $TPQ)
    }
  }

  return $parts
}

function Add-Bytes($ms, [byte[]]$bytes) {
  $ms.Write($bytes, 0, $bytes.Length)
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

function Build-Track([string]$TrackName, [int]$Channel, [int]$Program, $PartEvents) {
  $events = New-Object System.Collections.Generic.List[object]
  foreach ($e in $PartEvents) { $events.Add($e) | Out-Null }
  $events.Add([pscustomobject]@{ Tick = 0; Order = 2; Data = [byte[]]@([byte](0xC0 -bor $Channel), [byte]($Program -band 0x7F)) }) | Out-Null

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
  Add-Bytes $body ([byte[]]@([byte]0xFF, [byte]0x59, [byte]0x02, [byte]0xFF, [byte]0x01))

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

$parts = Generate-Parts
$totalTicks = [int]($Measures * $MeasureTicks)

$tracks = @(
  (Build-ConductorTrack $totalTicks),
  (Build-Track 'Violin I' 0 40 $parts.v1),
  (Build-Track 'Violin II' 1 40 $parts.v2),
  (Build-Track 'Viola' 2 41 $parts.va),
  (Build-Track 'Cello' 3 42 $parts.vc)
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
Write-Output "Dynamic profile: intensified velocity with phrase accents and section crescendos"
Write-Output "Instrumentation: Violin I, Violin II, Viola, Cello"
Write-Output "Absolute path: $absOutput"