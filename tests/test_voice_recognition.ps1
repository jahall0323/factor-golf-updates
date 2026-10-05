$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src/workers/Halliseum_Voice_Recognition.ps1')
function Assert($condition,[string]$message){if(-not$condition){throw $message}}
function Result([string]$text,[double]$confidence){return [pscustomobject]@{Text=$text;Confidence=$confidence;Grammar=[pscustomobject]@{Name='fixture'}}}
function FakeRecognizer($results){
 $queue=New-Object System.Collections.Queue
 foreach($result in $results){$queue.Enqueue($result)}
 $fake=[pscustomobject]@{queue=$queue;calls=0;timeout=0}
 $fake|Add-Member ScriptMethod Recognize {
  param([timespan]$timeout)
  $this.calls++;$this.timeout=$timeout.TotalSeconds
  if(-not$this.queue.Count){throw 'Unexpected extra recognition call'}
  $item=$this.queue.Dequeue()
  if($item -is [Exception]){throw $item}
  return $item
 }
 return $fake
}
$options=Get-FGVoiceOptions ([pscustomobject]@{})
Assert ($options.minConfidence -eq 0.48 -and $options.maxTurns -eq 8 -and $options.silenceSeconds -eq 15) 'Missing configuration must retain safe defaults'
$invalid=Get-FGVoiceOptions ([pscustomobject]@{VoiceRecognitionMinConfidence='bad';VoiceSilenceSeconds=-1;VoiceMaxFollowups=999})
Assert ($invalid.minConfidence -eq 0.48 -and $invalid.silenceSeconds -eq 15 -and $invalid.maxTurns -eq 8) 'Invalid configuration must not disable bounds'
$valid=Get-FGVoiceOptions ([pscustomobject]@{VoiceRecognitionMinConfidence=0.6;VoiceSilenceSeconds=20;VoiceMaxFollowups=4})
Assert ($valid.minConfidence -eq 0.6 -and $valid.silenceSeconds -eq 20 -and $valid.maxTurns -eq 4) 'Valid configuration must be honored'
$events=New-Object 'System.Collections.Generic.List[object]'
$report={param($event) $events.Add($event)}
$fake=FakeRecognizer @((Result 'back to golf' 0.35))
Assert ((Read-FGVoiceTurn $fake $options $report).action -eq 'exit') 'Exit below question threshold must still work'
Assert ($fake.calls -eq 1) 'Exit must stop recognition immediately'
$fake=FakeRecognizer @((Result 'why did it curve' 0.2),(Result 'why did it curve' 0.48))
$heard=Read-FGVoiceTurn $fake $options $report
Assert ($heard.action -eq 'question' -and $fake.calls -eq 2) 'Low-confidence question must retry before acceptance'
Assert ($fake.timeout -eq 15) 'Recognition timeout must use bounded silence setting'
$events.Clear()
$fake=FakeRecognizer @((Result 'noise' 0.1),(Result 'noise' 0.1),(Result 'noise' 0.1))
Assert ((Read-FGVoiceTurn $fake $options $report).action -eq 'exhausted') 'Repeated low confidence must terminate'
Assert ($fake.calls -eq 3 -and $events[-1].state -eq 'retries_exhausted') 'Retry bound and final diagnosis must be exact'
Assert ($events[-1].confidence -eq 0.1 -and $events[-1].text -eq 'noise') 'Terminal diagnosis must retain the rejected recognition evidence'
$fake=FakeRecognizer @((Result 'back to golf' 0.1),$null)
Assert ((Read-FGVoiceTurn $fake $options $report).action -eq 'silence') 'Very low-confidence exit must not be treated as a question or trusted command'
$fake=FakeRecognizer @((Result 'why does back to golf close the card' 0.8))
Assert ((Read-FGVoiceTurn $fake $options $report).action -eq 'question') 'Exit phrase embedded in a question must not close coaching'
$fake=FakeRecognizer @([InvalidOperationException]::new('fixture microphone disconnected'))
Assert ((Read-FGVoiceTurn $fake $options $report).action -eq 'error') 'Recognition exceptions must become visible terminal diagnostics'
Assert ($events[-1].error -match 'microphone disconnected') 'Exception detail must be retained'
Add-Type -AssemblyName System.Speech
$grammar=New-FGVoiceExitGrammar ([Globalization.CultureInfo]::GetCultureInfo('en-US'))
Assert ($grammar.Name -eq 'FactorGolfExit') 'Explicit exit grammar must construct under Windows PowerShell 5.1'
Write-Output 'PASS: bounded voice retries, exit commands, confidence thresholds, defaults, silence, error diagnostics and real grammar construction.'
