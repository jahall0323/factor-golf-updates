function Get-FGVoiceOptions($Config){
 $confidence=0.48;$seconds=15;$turns=8
 try{if($null -ne $Config.VoiceRecognitionMinConfidence){$n=[double]$Config.VoiceRecognitionMinConfidence;if($n -ge 0.1 -and $n -le 1){$confidence=$n}}}catch{}
 try{if($null -ne $Config.VoiceSilenceSeconds){$n=[int]$Config.VoiceSilenceSeconds;if($n -ge 3 -and $n -le 60){$seconds=$n}}}catch{}
 try{if($null -ne $Config.VoiceMaxFollowups){$n=[int]$Config.VoiceMaxFollowups;if($n -ge 1 -and $n -le 20){$turns=$n}}}catch{}
 return [pscustomobject]@{minConfidence=$confidence;silenceSeconds=$seconds;maxTurns=$turns;maxRejections=3;exitConfidence=0.25}
}

function New-FGVoiceExitGrammar([Globalization.CultureInfo]$Culture){
 $choices=New-Object System.Speech.Recognition.Choices
 $choices.Add([string[]]@('back to golf','close coach','close the coach','done',"I'm good",'that is all',"that's all"))
 $builder=New-Object System.Speech.Recognition.GrammarBuilder
 $builder.Culture=$Culture
 $builder.Append($choices)
 $grammar=New-Object System.Speech.Recognition.Grammar($builder)
 $grammar.Name='FactorGolfExit'
 return $grammar
}

function Read-FGVoiceTurn($Recognizer,$Options,[scriptblock]$Report){
 for($attempt=1;$attempt -le $Options.maxRejections;$attempt++){
  try{$result=$Recognizer.Recognize([TimeSpan]::FromSeconds($Options.silenceSeconds))}
  catch{
   & $Report ([pscustomobject]@{state='recognition_error';attempt=$attempt;error=$_.Exception.Message})
   return [pscustomobject]@{action='error';text=''}
  }
  if(-not$result -or [string]::IsNullOrWhiteSpace([string]$result.Text)){
   & $Report ([pscustomobject]@{state='silence';attempt=$attempt})
   return [pscustomobject]@{action='silence';text=''}
  }
  $text=([string]$result.Text).Trim();$confidence=[double]$result.Confidence
  $isExit=$text -match "(?i)^(back to golf|close( the)? coach|done|i'?m good|that'?s all|that is all)\s*[.!]?\s*$"
  $action='retry'
  if($isExit -and $confidence -ge $Options.exitConfidence){$action='exit'}
  elseif(-not$isExit -and $confidence -ge $Options.minConfidence){$action='question'}
  & $Report ([pscustomobject]@{state=$action;attempt=$attempt;text=$text;confidence=$confidence;threshold=$Options.minConfidence;grammar=[string]$result.Grammar.Name})
  if($action -ne 'retry'){return [pscustomobject]@{action=$action;text=$text}}
 }
 & $Report ([pscustomobject]@{state='retries_exhausted';attempt=$Options.maxRejections;text=$text;confidence=$confidence;threshold=$Options.minConfidence;grammar=[string]$result.Grammar.Name})
 return [pscustomobject]@{action='exhausted';text=''}
}
