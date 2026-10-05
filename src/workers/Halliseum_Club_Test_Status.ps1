function Get-FGClubTestView {
 param([string]$RequestId,$Status,[double]$ElapsedSeconds,[bool]$Exited)
 if($Status -and [string]$Status.request_id -ceq $RequestId -and
    [string]$Status.state -in @('club_detection_test_success','club_detection_test_failed') -and
    -not [string]::IsNullOrWhiteSpace([string]$Status.message)){
  return [pscustomobject]@{complete=$true;message=[string]$Status.message}
 }
 if($ElapsedSeconds -ge 30){return [pscustomobject]@{complete=$true;message='Club detection timed out. No club was verified. Keep the selector visible in GSPro and retry.'}}
 if($Exited){return [pscustomobject]@{complete=$true;message='Club detection stopped without a result. No club was verified. Check the saved capture and detection diagnostics.'}}
 return [pscustomobject]@{complete=$false;message='Reading the GSPro club selector...'}
}
