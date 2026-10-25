param(
 [string]$InputDeck='C:/Users/lenovo/Desktop/Research/Impact-melt-migration/tmp/research_ppt_build_20261025/candidate_base.pptx',
 [string]$OutputDeck='C:/Users/lenovo/Desktop/Research/Impact-melt-migration/tmp/research_ppt_build_20261025/candidate_media.pptx'
)
$ErrorActionPreference='Stop'
$buildRoot=Split-Path -Parent $PSCommandPath
$slots=Get-Content -LiteralPath (Join-Path $buildRoot 'video_slots.json') -Raw | ConvertFrom-Json
$existingPowerPoint=@(Get-Process -Name POWERPNT -ErrorAction SilentlyContinue).Count -gt 0
$pptApplication=$null;$deck=$null;$initialOpenCount=0;$previousAlerts=$null
try {
 $pptApplication=New-Object -ComObject PowerPoint.Application
 $initialOpenCount=$pptApplication.Presentations.Count
 $previousAlerts=$pptApplication.DisplayAlerts;$pptApplication.DisplayAlerts=1
 $deck=$pptApplication.Presentations.Open($InputDeck,0,0,0)
 $records=@()
 foreach($slot in $slots){
  if(-not (Test-Path -LiteralPath $slot.path)){throw "Missing movie $($slot.path)"}
  $slide=$deck.Slides.Item([int]$slot.slide)
  $poster=$null
  foreach($shape in $slide.Shapes){if($shape.AlternativeText -eq ('VIDEO_SLOT:'+$slot.key)){$poster=$shape;break}}
  if($null -eq $poster){
   $expectedX=([double]$slot.x+[double]$slot.w/2)*0.75
   $expectedY=([double]$slot.y+[double]$slot.h/2)*0.75
   $bestDistance=[double]::PositiveInfinity
   foreach($shape in $slide.Shapes){
    if($shape.Type -eq 13){
     $distance=[math]::Abs(($shape.Left+$shape.Width/2)-$expectedX)+[math]::Abs(($shape.Top+$shape.Height/2)-$expectedY)
     if($distance -lt $bestDistance){$bestDistance=$distance;$poster=$shape}
    }
   }
   if($bestDistance -gt 20){$poster=$null}
  }
  if($null -eq $poster){throw "Missing video poster $($slot.key)"}
  $left=$poster.Left;$top=$poster.Top;$width=$poster.Width;$height=$poster.Height
  $movie=$slide.Shapes.AddMediaObject2($slot.path,0,-1,$left,$top,$width,$height)
  $movie.Name='Video_'+$slot.key
  $movie.AlternativeText='Embedded research movie: '+$slot.key
  $movie.AnimationSettings.PlaySettings.PlayOnEntry=0
  $movie.AnimationSettings.PlaySettings.HideWhileNotPlaying=0
  $movie.AnimationSettings.PlaySettings.LoopUntilStopped=0
  $displayPicture='source video first frame'
  try {$movie.MediaFormat.SetDisplayPictureFromFile($slot.poster);$displayPicture='actual saved-state poster'} catch {}
  if($movie.Type -ne 16 -or $movie.MediaType -ne 3){throw "PowerPoint did not recognize $($slot.key) as a movie"}
  $poster.Delete()
  $records += [ordered]@{slide=[int]$slot.slide;key=$slot.key;shape_type=[int]$movie.Type;media_type=[int]$movie.MediaType;source=$slot.path;poster=$displayPicture}
  Write-Output ('EMBEDDED '+$slot.key)
 }
 if($records.Count -ne 7){throw 'Expected seven embedded movies'}
 $deck.SaveAs($OutputDeck,24)
 [ordered]@{slides=$deck.Slides.Count;embedded_movies=$records;status='PowerPoint recognized all seven native movie shapes'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $buildRoot 'native_movies_verification.json')
 Write-Output ('NATIVE_MEDIA_DECK '+$OutputDeck)
} finally {
 if($null -ne $deck){$deck.Close();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($deck)}
 if($null -ne $pptApplication){
  if($null -ne $previousAlerts){$pptApplication.DisplayAlerts=$previousAlerts}
  if(-not $existingPowerPoint -and $initialOpenCount -eq 0){$pptApplication.Quit()}
  [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($pptApplication)
 }
}
