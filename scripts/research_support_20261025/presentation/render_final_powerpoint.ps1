param([string]$InputDeck='C:/Users/lenovo/Desktop/Research/Impact-melt-migration/Output/research_presentation_20261025/Melt_migration_tests_and_mechanisms.pptx')
$ErrorActionPreference='Stop'
$buildRoot=Split-Path -Parent $PSCommandPath
$renderRoot=Join-Path $buildRoot 'powerpoint_renders'
New-Item -ItemType Directory -Path $renderRoot -Force | Out-Null
$existingPowerPoint=@(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue).Count -gt 0
$pptApplication=$null;$deck=$null;$initialOpenCount=0;$previousAlerts=$null
try {
 $pptApplication=New-Object -ComObject PowerPoint.Application
 $initialOpenCount=$pptApplication.Presentations.Count
 $previousAlerts=$pptApplication.DisplayAlerts;$pptApplication.DisplayAlerts=1
 $deck=$pptApplication.Presentations.Open($InputDeck,-1,0,0)
 $slides=@();$movies=@();$chartCount=0;$tableCount=0
 for($i=1;$i -le $deck.Slides.Count;$i++){
  $slide=$deck.Slides.Item($i)
  foreach($shape in $slide.Shapes){
   if($shape.Type -eq 16){$movies += [ordered]@{slide=$i;name=$shape.Name;media_type=[int]$shape.MediaType}}
   if($shape.HasChart -eq -1){$chartCount++}
   if($shape.HasTable -eq -1){$tableCount++}
  }
  $notes=''
  foreach($shape in $slide.NotesPage.Shapes){if($shape.HasTextFrame -eq -1){if($shape.TextFrame.HasText -eq -1){$notes+=$shape.TextFrame.TextRange.Text+"`n"}}}
  if(-not $notes.Contains('Sources')){throw "Slide $i has no source notes"}
  $png=Join-Path $renderRoot ('slide_{0:D2}.png' -f $i)
  $slide.Export($png,'PNG',1600,900)
  $slides += [ordered]@{slide=$i;notes_characters=$notes.Length;has_source_notes=$true;render=$png}
  Write-Output ('POWERPOINT_RENDER '+$i)
 }
 if($movies.Count -ne 7){throw "Expected seven movies, found $($movies.Count)"}
 if($deck.Slides.Count -ne 27){throw 'Unexpected slide count'}
 $report=[ordered]@{status='PowerPoint opened and rendered every final slide';path=$InputDeck;slides=$slides;movies=$movies;native_chart_count=$chartCount;native_table_count=$tableCount;playback_visually_tested=$false}
 $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $buildRoot 'powerpoint_final_verification.json')
} finally {
 if($null -ne $deck){$deck.Close();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($deck)}
 if($null -ne $pptApplication){
  if($null -ne $previousAlerts){$pptApplication.DisplayAlerts=$previousAlerts}
  if(-not $existingPowerPoint -and $initialOpenCount -eq 0){$pptApplication.Quit()}
  [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($pptApplication)
 }
}
