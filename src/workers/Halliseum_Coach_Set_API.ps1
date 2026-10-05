param(
    [Parameter(Mandatory=$true)][string]$SetStartIso,
    [Parameter(Mandatory=$true)][string]$Root,
    [Parameter(Mandatory=$true)][string]$AppDir
)

$ErrorActionPreference = "SilentlyContinue"
. (Join-Path $PSScriptRoot "Halliseum_Voice_Recognition.ps1")
try { Add-Type -AssemblyName System.Speech } catch {}
try { Add-Type -AssemblyName PresentationFramework } catch {}

$ConfigPath = Join-Path $AppDir "config.json"
$DefaultConfigPath = Join-Path $AppDir "config.default.json"
$config = if(Test-Path $ConfigPath){ Get-Content $ConfigPath -Raw | ConvertFrom-Json } else { Get-Content $DefaultConfigPath -Raw | ConvertFrom-Json }
$playerName='';try{if($config.PSObject.Properties.Name -contains 'PlayerName'){$playerName=([string]$config.PlayerName).Trim()}}catch{}
$nameInstruction=if($playerName){"The golfer's preferred name is $playerName. Use the name naturally and sparingly, not in every response."}else{"Do not address the golfer by a name or nickname."}
$personaInstruction=switch([string]$config.CoachPersona){
 'Professional / Clean'{'Persona: PG. Polished PGA-style coach. Encouraging and direct. No profanity and minimal sarcasm.'}
 'One of the Boys'{'Persona: R. Very casual golf buddy. Stronger language, trash talk and sarcasm may be used when they fit, but keep the coaching respectful, useful and data-grounded.'}
 'Hood Golf'{'Persona: HOOD GOLF / R. Use the same useful, direct golf-buddy foundation as One of the Boys, but deliver it with strong natural AAVE-style phrasing, cadence and slang. Profanity, playful trash talk and colorful everyday analogies are welcome when they fit. Keep the language readable and authentic rather than exaggerated. Never use racial slurs, racial stereotypes, or imply that any race talks one way. Golf accuracy, data honesty and coaching priority always come first.'}
 'Extreme'{'Persona: EXTREME / R+. Be a vulgar, rowdy drunk-golf-buddy-style coach. Use heavy profanity naturally, sarcastic trash talk, and intentionally corny real-world analogies that tie directly back to the golf problem. The FIRST coaching response in each set must contain at least one ridiculous everyday-life analogy and at least one corny dad joke somewhere in the spoken coaching. Keep the joke brief so it does not bury the golf lesson. Follow-up answers should keep the same rowdy style and use more analogies when helpful, but do not force the same joke repeatedly. Never use slurs, threats, hateful language, or sexual harassment. Coaching accuracy, BLP limitations, data honesty, and the one-primary-fix rule never change.'}
 default{'Persona: PG-13. Relaxed golf buddy. Conversational, lightly sarcastic and humorous, with occasional mild profanity when it fits.'}
}
$coachingLevel='Rookie';try{if($config.PSObject.Properties.Name -contains 'CoachingLevel' -and $config.CoachingLevel){$coachingLevel=[string]$config.CoachingLevel}}catch{}
$coachingLevelInstruction=switch($coachingLevel){
 'Amateur'{'Golfer experience: AMATEUR. Assume the golfer already understands grip, stance, posture, alignment, ball position, basic clubface/path ideas, and the difference between solid contact and common mishits. Do not reteach those fundamentals unless the evidence shows one of them is causing the pattern. Coach toward repeatability: strike quality, start line, curvature, dispersion, distance control and delivery. Use normal golf terminology without defining every word. Explain cause and effect and include relevant BLP or SwingNerds metrics when they materially support the diagnosis. You may mention one secondary issue, but keep one clear primary priority. Expect tighter consistency than Rookie mode.'}
 'Advanced'{'Golfer experience: PRO / ADVANCED. Assume the golfer has strong fundamentals, understands ball flight and launch-monitor language, and can execute specific swing feels without beginner setup instruction. Do not default to grip, stance, posture, alignment or ball-position lessons unless the data or video clearly identifies a fundamental breakdown. Focus on pattern quality, delivery windows, strike location, face/path relationship when actually available, attack angle, launch, spin/axis, speed, dispersion, body sequencing and shot-shape optimization. Be concise and technical. Separate tiny optimization opportunities from real faults and use tight consistency expectations. Preserve one clear primary priority and never invent unavailable metrics.'}
 default{'Golfer experience: ROOKIE. Assume the golfer is still building the basic golf operating system. When relevant, explicitly teach fundamentals such as grip, stance width, posture, alignment, ball position, balance, centered contact, simple backswing/downswing concepts and what basic ball flight means. Explain golf terms in plain English before leaning on them. Tell the golfer not only WHAT to change but WHY that fundamental matters and what the correct motion should feel like. Keep the lesson small: one main correction, at most one secondary observation, and only one or two simple feels for the next swings. Use setup checkpoints freely when they help. Avoid unnecessary metric jargon and treat wider beginner variability and occasional mishits as normal while still identifying repeatable patterns.'}
}
$coachingLevelInstruction += ' Golfer Experience changes the assumed golf knowledge, the fundamentals that need teaching, the performance expectations, and the depth/language of instruction. It must never change measured facts, fabricate evidence, soften or exaggerate the diagnosis, or override Bushnell/SwingNerds data limitations. A Rookie may need a fundamental explained from scratch; an Amateur should usually be coached through consistency and cause/effect; a Pro / Advanced golfer should usually be coached through precision and optimization.'
$addressPrefix=if($playerName){$playerName+', '}else{''}
$ttsVoice=[string]$config.TTSVoice;if(@('marin','cedar') -notcontains $ttsVoice){$ttsVoice='marin'}

$out = Join-Path $Root "UltimateCoach"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$runtimePath = Join-Path $out "coach_runtime.json"
$budgetPath = Join-Path $out "budget.json"
$requestId = [guid]::NewGuid().ToString("N").Substring(0,8)
$start = [datetimeoffset]::Parse($SetStartIso).LocalDateTime

function Write-Runtime([string]$state,[string]$message,[bool]$dismiss=$false) {
    [ordered]@{
        request_id=$requestId
        state=$state
        message=$message
        dismiss=$dismiss
        updated=(Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 5 | Set-Content $runtimePath -Encoding UTF8
}

function Get-ApiKey {
    $secretFile = Join-Path $AppDir "secrets\openai_api_key.dpapi"
    if(-not (Test-Path $secretFile)){ return $null }
    try {
        $enc = (Get-Content $secretFile -Raw).Trim()
        $sec = ConvertTo-SecureString $enc
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    } catch { return $null }
}

function Get-BudgetState {
    $month=(Get-Date -Format "yyyy-MM")
    if(Test-Path $budgetPath){
        try {
            $b=Get-Content $budgetPath -Raw | ConvertFrom-Json
            if([string]$b.month -eq $month){ return $b }
        } catch {}
    }
    return [pscustomobject]@{month=$month;spent_estimate_usd=0.0;coach_calls=0;followup_calls=0;tts_calls=0;voice_seconds=0.0}
}

function Save-BudgetState($b){
    $b | ConvertTo-Json -Depth 5 | Set-Content $budgetPath -Encoding UTF8
}

function Add-BudgetCost([double]$cost,[string]$kind,[double]$voiceSeconds=0){
    $b=Get-BudgetState
    $b.spent_estimate_usd=[math]::Round(([double]$b.spent_estimate_usd + $cost),6)
    if($kind -eq "coach"){$b.coach_calls=[int]$b.coach_calls+1}
    elseif($kind -eq "followup"){$b.followup_calls=[int]$b.followup_calls+1}
    elseif($kind -eq "tts"){$b.tts_calls=[int]$b.tts_calls+1; $b.voice_seconds=[math]::Round(([double]$b.voice_seconds+$voiceSeconds),1)}
    Save-BudgetState $b
}

function Test-BudgetAvailable {
    $b=Get-BudgetState
    $limit=[double]$config.MonthlyBudgetUSD
    # Keep a small reserve so a single request cannot push Halliseum over the requested cap.
    return ([double]$b.spent_estimate_usd -lt [math]::Max(0,($limit-0.25)))
}

function Get-Median($values){
    $a=@($values | Where-Object {$null -ne $_} | ForEach-Object {[double]$_} | Sort-Object)
    if($a.Count -eq 0){return $null}
    $m=[int][math]::Floor($a.Count/2)
    if($a.Count % 2 -eq 1){return [double]$a[$m]}
    return ([double]$a[$m-1]+[double]$a[$m])/2.0
}

function Get-Mean($values){
    $a=@($values | Where-Object {$null -ne $_} | ForEach-Object {[double]$_})
    if($a.Count -eq 0){return $null}
    return [double](($a | Measure-Object -Average).Average)
}

function Parse-Shots {
    $log = Join-Path $env:LOCALAPPDATA "SwingNerdsClip\gspro_shots.log"
    $arr = @()
    if (-not (Test-Path $log)) { return $arr }
    foreach ($line in (Get-Content $log -Tail 1800)) {
        if ($line -match '^\[(?<ts>[0-9\-: .]+)\] \[LastShot #(?<num>\d+)\] (?<json>\{.*\})$') {
            try {
                $ts = [datetime]::Parse($matches['ts'])
                if ($ts -ge $start) {
                    $j = $matches['json'] | ConvertFrom-Json
                    $arr += [pscustomobject]@{
                        shot=[int]$matches['num']; time=$ts.ToString("o"); club=[string]$j.club
                        carry=$(if($null -ne $j.Carry){[math]::Round([double]$j.Carry,1)}else{$null})
                        total=$(if($null -ne $j.Total){[math]::Round([double]$j.Total,1)}elseif($null -ne $j.TotalDistance){[math]::Round([double]$j.TotalDistance,1)}else{$null})
                        ball_speed=$(if($null -ne $j.BallSpeed){[math]::Round([double]$j.BallSpeed,1)}else{$null})
                        back_spin=$(if($null -ne $j.BackSpin){[math]::Round([double]$j.BackSpin,0)}else{$null})
                        side_spin=$(if($null -ne $j.SideSpin){[math]::Round([double]$j.SideSpin,0)}else{$null})
                        hla=$(if($null -ne $j.HLA){[math]::Round([double]$j.HLA,1)}else{$null})
                        vla=$(if($null -ne $j.VLA){[math]::Round([double]$j.VLA,1)}else{$null})
                        offline=$(if($null -ne $j.Offline){[math]::Round([double]$j.Offline,1)}else{$null})
                        spin_axis=$(if($null -ne $j.rawSpinAxis){[math]::Round([double]$j.rawSpinAxis,1)}else{$null})
                        club_speed=$(if($j.ClubSpeed -and [double]$j.ClubSpeed -gt 0){[math]::Round([double]$j.ClubSpeed,1)}else{$null})
                        path=$(if($null -ne $j.Path -and [math]::Abs([double]$j.Path) -lt 25){[math]::Round([double]$j.Path,1)}else{$null})
                        aoa=$(if($null -ne $j.AoA -and [math]::Abs([double]$j.AoA) -lt 25){[math]::Round([double]$j.AoA,1)}else{$null})
                        smash=$(if($j.SmashFactor -and [double]$j.SmashFactor -gt 0){[math]::Round([double]$j.SmashFactor,2)}else{$null})
                    }
                }
            } catch {}
        }
    }
    return @($arr | Sort-Object shot -Unique)
}

function Parse-SwingNerds {
    $hist = Join-Path $Root "SwingNerds_UIA\swingnerds_history.jsonl"
    $arr = @(); $seen=@{}
    if (-not (Test-Path $hist)) { return $arr }
    foreach ($line in Get-Content $hist) {
        try {
            $j = $line | ConvertFrom-Json
            $t=[datetimeoffset]::Parse($j.captured_at).LocalDateTime
            if ($t -ge $start) {
                $sig="$($j.head_drift)|$($j.lead_arm_impact)|$($j.tempo)|$($j.upper_body_lean_top)|$($j.carry)|$($j.ball_speed)|$($j.smash)"
                if(-not $seen.ContainsKey($sig)){$seen[$sig]=$true;$arr += $j}
            }
        } catch {}
    }
    return $arr
}

function Build-CompactSummary($allShots,$sn){
    $groups=@($allShots | Group-Object club | Sort-Object Count -Descending)
    $primaryClub=if($groups.Count -gt 0){[string]$groups[0].Name}else{"UNKNOWN"}
    $shots=@($allShots | Where-Object {$_.club -eq $primaryClub})
    $carryMed=Get-Median ($shots | ForEach-Object {$_.carry})
    $ballMed=Get-Median ($shots | ForEach-Object {$_.ball_speed})
    $possible=@()
    if($shots.Count -ge 5 -and $carryMed -and $ballMed){
        $possible=@($shots | Where-Object {$_.carry -lt (0.60*$carryMed) -and $_.ball_speed -lt (0.75*$ballMed)} | ForEach-Object {$_.shot})
    }
    $reps=@($shots)
    if($shots.Count -gt 8){
        $sorted=@($shots | Sort-Object carry)
        $idx=@(0,[int][math]::Floor(($sorted.Count-1)*0.25),[int][math]::Floor(($sorted.Count-1)*0.5),[int][math]::Floor(($sorted.Count-1)*0.75),$sorted.Count-1) | Select-Object -Unique
        $reps=@($idx | ForEach-Object {$sorted[$_]})
    }
    $warnings=@()
    if($groups.Count -gt 1){
        $other=($groups | Select-Object -Skip 1 | ForEach-Object {"$($_.Name):$($_.Count)"}) -join ", "
        $warnings += "Multiple clubs were detected. Bag Session mode is disabled; analyze only the primary club $primaryClub. Other club shots: $other."
    }
    return [ordered]@{
        primary_club=$primaryClub
        shots_in_primary=$shots.Count
        shots_total=$allShots.Count
        possible_low_energy_mishit_shot_numbers=$possible
        warnings=$warnings
        stats=[ordered]@{
            carry_median=$(if($carryMed){[math]::Round($carryMed,1)}else{$null})
            carry_mean=$(if($shots.Count){[math]::Round((Get-Mean ($shots|% carry)),1)}else{$null})
            carry_min=$(if($shots.Count){($shots|Measure-Object carry -Minimum).Minimum}else{$null})
            carry_max=$(if($shots.Count){($shots|Measure-Object carry -Maximum).Maximum}else{$null})
            total_median=$(if(@($shots|? {$null -ne $_.total}).Count){[math]::Round((Get-Median ($shots|% total)),1)}else{$null})
            ball_speed_median=$(if($ballMed){[math]::Round($ballMed,1)}else{$null})
            club_speed_median=$(if(@($shots|? {$null -ne $_.club_speed}).Count){[math]::Round((Get-Median ($shots|% club_speed)),1)}else{$null})
            offline_median=$(if($shots.Count){[math]::Round((Get-Median ($shots|% offline)),1)}else{$null})
            offline_mean=$(if($shots.Count){[math]::Round((Get-Mean ($shots|% offline)),1)}else{$null})
            spin_axis_median=$(if($shots.Count){[math]::Round((Get-Median ($shots|% spin_axis)),1)}else{$null})
            vla_median=$(if(@($shots|? {$null -ne $_.vla}).Count){[math]::Round((Get-Median ($shots|% vla)),1)}else{$null})
            hla_median=$(if(@($shots|? {$null -ne $_.hla}).Count){[math]::Round((Get-Median ($shots|% hla)),1)}else{$null})
            back_spin_median=$(if(@($shots|? {$null -ne $_.back_spin}).Count){[math]::Round((Get-Median ($shots|% back_spin)),0)}else{$null})
            path_median=$(if(@($shots|? {$null -ne $_.path}).Count){[math]::Round((Get-Median ($shots|% path)),1)}else{$null})
            aoa_median=$(if(@($shots|? {$null -ne $_.aoa}).Count){[math]::Round((Get-Median ($shots|% aoa)),1)}else{$null})
            smash_median=$(if(@($shots|? {$null -ne $_.smash}).Count){[math]::Round((Get-Median ($shots|% smash)),2)}else{$null})
        }
        representative_shots=$reps
        visual_shots=@($shots | Select-Object -Last 20 | ForEach-Object {[ordered]@{shot=$_.shot;carry=$_.carry;total=$_.total;offline=$_.offline;vla=$_.vla;hla=$_.hla;ball_speed=$_.ball_speed;path=$_.path;aoa=$_.aoa}})
        swingnerds_samples=@($sn | Select-Object -Last 8)
    }
}

function Get-ResponseText($resp){
    try {
        foreach($item in @($resp.output)){
            if([string]$item.type -eq "message"){
                foreach($c in @($item.content)){
                    if([string]$c.type -eq "output_text" -and $c.text){ return [string]$c.text }
                }
            }
        }
    } catch {}
    return $null
}

function Get-OpenAIErrorDetail($err){
    $detail=""
    try{$detail=[string]$err.ErrorDetails.Message}catch{}
    if(-not $detail){
        try{
            $resp=$err.Exception.Response
            if($resp){$stream=$resp.GetResponseStream();if($stream){$reader=New-Object IO.StreamReader($stream);try{$detail=$reader.ReadToEnd()}finally{$reader.Dispose()}}}
        }catch{}
    }
    if(-not $detail){try{$detail=[string]$err.Exception.Message}catch{}}
    if($detail){$detail=[regex]::Replace($detail,'sk-[A-Za-z0-9_-]+','[REDACTED_API_KEY]')}
    if($detail.Length -gt 1400){$detail=$detail.Substring(0,1400)}
    return $detail
}

function Invoke-ResponsesCall([string]$model,[string]$instructions,[string]$userInput,[int]$maxTokens){
    $key=Get-ApiKey
    if(-not $key){throw "OpenAI API key is not configured."}
    $headers=@{Authorization="Bearer $key"}
    # Windows PowerShell 5.1 can send string request bodies using a legacy/default encoding.
    # Halliseum shot/SwingNerds data contains legitimate Unicode (for example degree signs).
    # Build JSON normally, then send the exact UTF-8 bytes OpenAI expects.
    $body=[ordered]@{
        model=$model
        instructions=$instructions
        input=$userInput
        store=$false
        max_output_tokens=$maxTokens
    }
    $json=$body | ConvertTo-Json -Depth 20 -Compress
    $jsonBytes=[System.Text.Encoding]::UTF8.GetBytes($json)
    try{
        return Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/responses" -Headers $headers -ContentType "application/json; charset=utf-8" -Body $jsonBytes -TimeoutSec 120
    } catch {
        $detail=Get-OpenAIErrorDetail $_
        if(-not $detail){$detail=$_.Exception.Message}
        throw ("OpenAI API request failed: "+$detail)
    }
}

function Invoke-TextModel([string]$model,[string]$instructions,[string]$userInput,[string]$kind,[bool]$structured=$false){
    if(-not (Test-BudgetAvailable)){ throw "Factor Golf monthly AI budget limit reached." }
    if($structured){
        $instructions += @"

Return ONLY one valid JSON object with these exact keys and no markdown fences:
club, shot_count, headline, did_well, biggest_issue, secondary_issue, ball_effect, feel_1, feel_2, next_set, body_metric_note, confidence_note, spoken_text.
Use a string for every value except shot_count, which must be an integer.
Do not omit keys. Do not add keys.
Projector-card writing rules: headline 8 words max; did_well 18 words max; biggest_issue 18 words max; secondary_issue 16 words max; ball_effect 18 words max; feel_1 and feel_2 12 words max each; next_set 20 words max; body_metric_note 18 words max; confidence_note 18 words max. spoken_text may be 60-100 words.
"@
    }
    $resp=Invoke-ResponsesCall -model $model -instructions $instructions -userInput $userInput -maxTokens $(if($structured){1400}else{600})
    $text=Get-ResponseText $resp
    if(-not $text){ throw "OpenAI returned no readable text." }
    $inputTokens=0;$outputTokens=0;$cached=0
    try{$inputTokens=[double]$resp.usage.input_tokens}catch{}
    try{$outputTokens=[double]$resp.usage.output_tokens}catch{}
    try{$cached=[double]$resp.usage.input_tokens_details.cached_tokens}catch{}
    if($kind -eq "coach"){
        $inRate=[double]$config.CoachModelInputPerMillion;$outRate=[double]$config.CoachModelOutputPerMillion
        $cachedRate=if($config.PSObject.Properties.Name -contains "CoachModelCachedInputPerMillion"){[double]$config.CoachModelCachedInputPerMillion}else{$inRate*0.1}
    } else {
        $inRate=[double]$config.FollowupModelInputPerMillion;$outRate=[double]$config.FollowupModelOutputPerMillion
        $cachedRate=if($config.PSObject.Properties.Name -contains "FollowupModelCachedInputPerMillion"){[double]$config.FollowupModelCachedInputPerMillion}else{$inRate*0.1}
    }
    $nonCached=[math]::Max(0,$inputTokens-$cached)
    $cost=(($nonCached*$inRate)+($cached*$cachedRate)+($outputTokens*$outRate))/1000000.0
    Add-BudgetCost $cost $kind
    return [pscustomobject]@{text=$text;response=$resp;cost=$cost;model=$model}
}

function Convert-CoachJson([string]$text,$summary){
    try{
        $t=$text.Trim()
        if($t.StartsWith('```')){$t=$t -replace '^```(?:json)?\s*','';$t=$t -replace '\s*```$',''}
        $a=$t.IndexOf('{');$b=$t.LastIndexOf('}')
        if($a -ge 0 -and $b -gt $a){$t=$t.Substring($a,$b-$a+1)}
        return ($t | ConvertFrom-Json)
    } catch {
        # Never throw away a usable coach answer just because formatting was imperfect.
        return [pscustomobject]@{
            club=[string]$summary.primary_club
            shot_count=[int]$summary.shots_in_primary
            headline="Coach feedback"
            did_well="Your set was captured successfully."
            biggest_issue=$text
            secondary_issue="No secondary issue identified yet."
            ball_effect="See spoken coaching for the shot-pattern explanation."
            feel_1="Keep the next set focused on one simple feel."
            feel_2="Do not add another change until the next set is reviewed."
            next_set="Hit 3 to 5 more shots with the same club."
            body_metric_note="SwingNerds metrics were included in the coaching request when available."
            confidence_note="The AI response was usable but did not return the requested JSON format."
            spoken_text=$text
        }
    }
}

function Get-WavDurationSeconds([string]$path){
    try {
        $fs=[IO.File]::OpenRead($path);$br=New-Object IO.BinaryReader($fs)
        try {
            $null=$br.ReadBytes(12);$byteRate=0;$dataSize=0
            while($fs.Position -lt $fs.Length-8){
                $id=[Text.Encoding]::ASCII.GetString($br.ReadBytes(4));$size=$br.ReadInt32()
                if($id -eq "fmt "){
                    $null=$br.ReadInt16();$null=$br.ReadInt16();$null=$br.ReadInt32();$byteRate=$br.ReadInt32();$fs.Position += [math]::Max(0,$size-12)
                } elseif($id -eq "data"){$dataSize=$size;break}
                else{$fs.Position += $size}
            }
            if($byteRate -gt 0 -and $dataSize -gt 0){return [double]$dataSize/[double]$byteRate}
        } finally {$br.Close();$fs.Close()}
    } catch {}
    return 0
}

function Get-EstimatedSpeechSeconds([string]$text){
    if(-not $text){return 0}
    $words=@($text -split '\s+' | Where-Object {$_}).Count
    if($words -lt 1){return 0}
    return [math]::Max(2.0,[double]$words/2.55)
}

function Play-NaturalAudio([string]$path,[double]$fallbackSeconds){
    Add-Type -AssemblyName PresentationCore
    $player=New-Object System.Windows.Media.MediaPlayer
    try{
        $player.Open((New-Object System.Uri -ArgumentList $path))
        $deadline=(Get-Date).AddSeconds(5)
        while(-not $player.NaturalDuration.HasTimeSpan -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 100}
        $seconds=$fallbackSeconds
        if($player.NaturalDuration.HasTimeSpan){$seconds=[math]::Max(1.0,$player.NaturalDuration.TimeSpan.TotalSeconds)}
        $player.Volume=1.0
        $player.Play()
        Start-Sleep -Milliseconds ([int](($seconds+0.45)*1000))
        $player.Stop()
        return $seconds
    } finally {try{$player.Close()}catch{}}
}

function Speak-Natural([string]$text,[string]$tag){
    if(-not [bool]$config.SpeakCoachResponse -or -not $text){return}
    if(-not (Test-BudgetAvailable)){return}
    $key=Get-ApiKey;if(-not $key){return}
    $format=if($config.PSObject.Properties.Name -contains 'TTSFormat' -and $config.TTSFormat){[string]$config.TTSFormat}else{'mp3'}
    $ext=if($format -eq 'wav'){'wav'}else{'mp3'}
    $audioPath=Join-Path $out ("voice_"+$requestId+"_"+$tag+"."+$ext)
    try {
        $headers=@{Authorization="Bearer $key"}
        $voiceStyle=if($config.PSObject.Properties.Name -contains 'VoiceStyle' -and $config.VoiceStyle){[string]$config.VoiceStyle}else{'Warm, natural, conversational golf coach.'}
        $body=[ordered]@{
            model=[string]$config.TTSModel
            voice=$ttsVoice
            input=$text
            instructions=$voiceStyle
            response_format=$format
            speed=1.0
        } | ConvertTo-Json -Depth 6 -Compress
        $bodyBytes=[System.Text.Encoding]::UTF8.GetBytes($body)
        Invoke-WebRequest -Method Post -Uri "https://api.openai.com/v1/audio/speech" -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bodyBytes -OutFile $audioPath -TimeoutSec 120 | Out-Null
        if(-not (Test-Path $audioPath) -or (Get-Item $audioPath).Length -lt 1000){throw 'OpenAI voice file was empty or invalid.'}
        $estimate=Get-EstimatedSpeechSeconds $text
        $sec=Play-NaturalAudio $audioPath $estimate
        $textTokens=[math]::Ceiling($text.Length/4.0)
        $audioTokens=[math]::Ceiling($sec*60.0)
        $cost=(($textTokens*[double]$config.TTSInputPerMillion)+($audioTokens*[double]$config.TTSAudioOutputPerMillion))/1000000.0
        Add-BudgetCost $cost "tts" $sec
        try{Remove-Item (Join-Path $out 'tts_error_latest.txt') -Force -ErrorAction SilentlyContinue}catch{}
    } catch {
        $msg=$_.Exception.Message
        try{$msg | Set-Content (Join-Path $out "tts_error_latest.txt") -Encoding UTF8}catch{}
        Write-Runtime 'voice_error' 'Natural OpenAI voice failed. Coach Card stays visible; local robot voice is disabled.'
        $allow=$false;try{$allow=[bool]$config.AllowWindowsTTSFallback}catch{}
        if($allow){try{Add-Type -AssemblyName System.Speech;$syn=New-Object System.Speech.Synthesis.SpeechSynthesizer;$syn.Speak($text);$syn.Dispose()}catch{}}
    }
}

function Restore-GSProFocus {
    try{$gs=Get-Process -Name "GSPro" -ErrorAction SilentlyContinue|Select-Object -First 1;if($gs){$ws=New-Object -ComObject WScript.Shell;[void]$ws.AppActivate($gs.Id)}}catch{}
}

Write-Runtime "collecting" "Closing the set and building the local summary."
$shots=@(Parse-Shots)
$sn=@(Parse-SwingNerds)
$rawPackage=[ordered]@{request_id=$requestId;set_started=$SetStartIso;set_ended=(Get-Date).ToString("o");shot_count=$shots.Count;shots=$shots;swingnerds=$sn}
$rawPath=Join-Path $out ("coach_set_"+(Get-Date -Format "yyyyMMdd_HHmmss")+".json")
$rawPackage | ConvertTo-Json -Depth 12 | Set-Content $rawPath -Encoding UTF8

if($shots.Count -eq 0){
    $msg="No new GSPro shots were found. No AI call was made."
    Set-Content (Join-Path $out "last_result.txt") $msg -Encoding UTF8
    Write-Runtime "idle" $msg $true
    Restore-GSProFocus
    exit 2
}

$summary=Build-CompactSummary $shots $sn
$compactPath=Join-Path $out "latest_local_summary.json"
$summary | ConvertTo-Json -Depth 12 | Set-Content $compactPath -Encoding UTF8

if(-not (Test-BudgetAvailable)){
    $msg="Factor Golf AI budget limit reached. Your set was saved locally and no paid AI call was made."
    Set-Content (Join-Path $out "last_result.txt") $msg -Encoding UTF8
    Write-Runtime "budget_stop" $msg $true
    Restore-GSProFocus
    exit 3
}

if(-not (Get-ApiKey)){
    $fallback=[ordered]@{
        club=[string]$summary.primary_club;shot_count=[int]$summary.shots_in_primary
        headline="API setup needed";did_well="Your set was captured correctly.";biggest_issue="Your shot set was captured correctly, but the OpenAI API key has not been configured on this PC."
        secondary_issue="No secondary issue identified.";ball_effect="No paid coaching call was made.";feel_1="Run SETUP_OPENAI_API_KEY.bat once.";feel_2="Then repeat a short test set."
        next_set="After API setup, hit 3 to 5 shots and use End Set & Coach Me."
        body_metric_note="SwingNerds data was saved locally.";confidence_note="Data capture is working; AI handoff is not configured yet.";spoken_text=($addressPrefix+"your golf data was captured, but the OpenAI API key still needs to be set up on this PC. No paid call was made.")
    }
    $fallback | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out "latest_coach_response.json") -Encoding UTF8
    Write-Runtime "needs_api_key" "API key setup is required. No paid call was made."
    $card=Join-Path $AppDir "workers\Halliseum_Coach_Card.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$card`" -Root `"$Root`" -AppDir `"$AppDir`"" -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 8
    Write-Runtime "idle" "API key setup is required." $true
    Restore-GSProFocus
    exit 4
}

Write-Runtime "thinking" "Local summary complete. Coach AI is analyzing this club set."
$instructions=@"
You are a PGA-style golf coach for a golfer using the home simulator Factor Golf Sim Control Center.
$nameInstruction
$personaInstruction
$coachingLevelInstruction
Coach ONE club set only. Start with one short did_well statement about a genuine positive pattern from this set. Identify up to TWO meaningful recurring issues. Make biggest_issue the clear FIRST priority. Put the other issue in secondary_issue. Do not ask the golfer to actively fix the secondary issue unless it directly supports the primary fix. Explain simply what the primary issue did to the ball, then give only one or two simple feels for the next set.
Use pattern evidence, not one bad shot. Treat obvious low-energy mishits as possible mishits, but do not hide recurring misses.
Bushnell Launch Pro caveats: this is a one-dot club-marker setup. FaceToTarget and FaceToPath zero placeholders are not measured face data and must never be used. Club data can occasionally fail. Do not build a diagnosis around missing or suspicious club metrics, especially AoA. Ball data and repeated patterns take priority.
SwingNerds body metrics are camera-derived values from its Active Coach panel. Use them when they line up with the ball-flight pattern.
Do not give generic setup-reference guidance on the coaching card. Club setup fundamentals live in Factor Golf's separate Club Cheat Sheet. Only discuss setup here if it is directly supported by measured/camera evidence and is part of the primary diagnosis.
Match terminology, fundamentals, and explanation depth to the selected Golfer Experience above. No more than two swing thoughts.
The spoken_text should be about 60 to 100 words and sound like a real coach talking beside the hitting mat, not reading a report.
"@
$apiSummary=[ordered]@{
    primary_club=$summary.primary_club
    shots_in_primary=$summary.shots_in_primary
    possible_low_energy_mishit_shot_numbers=$summary.possible_low_energy_mishit_shot_numbers
    warnings=$summary.warnings
    stats=$summary.stats
    representative_shots=$summary.representative_shots
    swingnerds_samples=$summary.swingnerds_samples
}
$coachInput="LOCAL FACTOR GOLF SUMMARY:`n"+($apiSummary|ConvertTo-Json -Depth 12 -Compress)
try {
    try {
        $ai=Invoke-TextModel -model ([string]$config.CoachModel) -instructions $instructions -userInput $coachInput -kind "coach" -structured $true
    } catch {
        $primaryError=$_.Exception.Message
        Write-Runtime "retrying" "Primary coach request was rejected. Retrying with the compatibility model."
        $ai=Invoke-TextModel -model "gpt-6-luna" -instructions $instructions -userInput $coachInput -kind "coach" -structured $true
    }
    $coach=Convert-CoachJson ([string]$ai.text) $summary
} catch {
    $detail=$_.Exception.Message
    if($primaryError){$detail="Primary: $primaryError`nFallback: $detail"}
    $detail | Set-Content (Join-Path $out "api_error_latest.txt") -Encoding UTF8
    $msg="Coach AI call failed. Showing the local shot-data card only; no AI diagnosis was generated."
    Set-Content (Join-Path $out "last_result.txt") $msg -Encoding UTF8
    $localOnly=[ordered]@{
        club=[string]$summary.primary_club;shot_count=[int]$summary.shots_in_primary;headline="LOCAL SHOT DATA - COACH AI UNAVAILABLE"
        did_well="Your set was captured and saved locally."
        biggest_issue="Your set was captured and summarized locally, but the OpenAI coaching request failed."
        secondary_issue="No secondary issue is being claimed from a failed request."
        ball_effect="No swing diagnosis is being claimed from this failed AI request."
        feel_1="Keep your next swings smooth.";feel_2="Do not make a new swing change from this error card."
        next_set="Your shot data is safe. Retry coaching after the API connection is fixed."
        body_metric_note="SwingNerds/body data was preserved locally when available.";confidence_note="LOCAL DATA ONLY - no AI diagnosis.";spoken_text=""
    }
    $localOnly | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $out "latest_coach_response.json") -Encoding UTF8
    Write-Runtime "error_card" $msg
    $cardScript=Join-Path $AppDir "workers\Halliseum_Coach_Card.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cardScript`" -Root `"$Root`" -AppDir `"$AppDir`"" -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 12
    Write-Runtime "idle" "Coach AI failed; local shot data was saved." $true
    Restore-GSProFocus
    exit 5
}

$responsePath=Join-Path $out "latest_coach_response.json"
$coach | ConvertTo-Json -Depth 10 | Set-Content $responsePath -Encoding UTF8
try{
    $reportDir=Join-Path $out 'Session Reports';New-Item -ItemType Directory -Path $reportDir -Force|Out-Null
    $reportName=('coach_report_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+(([string]$summary.primary_club)-replace '[^A-Za-z0-9_-]','_')+'.json')
    [ordered]@{created=(Get-Date).ToString('o');set_started=$SetStartIso;club=$summary.primary_club;summary=$summary;coach=$coach;raw_set_file=$rawPath}|ConvertTo-Json -Depth 14|Set-Content (Join-Path $reportDir $reportName) -Encoding UTF8
}catch{}
$coach.spoken_text | Set-Content (Join-Path $out "last_result.txt") -Encoding UTF8

Write-Runtime "card" "Coach card is on screen. Spoken feedback is starting."
$cardScript=Join-Path $AppDir "workers\Halliseum_Coach_Card.ps1"
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cardScript`" -Root `"$Root`" -AppDir `"$AppDir`"" -WindowStyle Hidden | Out-Null
Start-Sleep -Milliseconds 800
Speak-Natural ([string]$coach.spoken_text) "coach"

if(-not [bool]$config.AutoVoiceFollowup){
    Start-Sleep -Seconds ([int]$config.VoiceSilenceSeconds)
    Write-Runtime "idle" "Coaching complete." $true
    Restore-GSProFocus
    exit 0
}

$voiceOptions=Get-FGVoiceOptions $config
$voiceDiagnosticPath=Join-Path $out 'voice_recognition_status.json'
$script:voiceEngineId='';$script:voiceCulture='en-US'
function Write-VoiceDiagnostic($event){
    try{
        [ordered]@{request_id=$requestId;updated=(Get-Date).ToString('o');input='Windows default audio input';engine_id=$script:voiceEngineId;culture=$script:voiceCulture;min_confidence=$voiceOptions.minConfidence;silence_seconds=$voiceOptions.silenceSeconds;event=$event}|ConvertTo-Json -Depth 6|Set-Content $voiceDiagnosticPath -Encoding UTF8 -ErrorAction Stop
    }catch{}
}
$history=New-Object System.Collections.Generic.List[object]
$turn=0
$recognizer=$null
try {
    Add-Type -AssemblyName System.Speech -ErrorAction Stop
    $culture=[Globalization.CultureInfo]::GetCultureInfo("en-US")
    $recognizer=New-Object System.Speech.Recognition.SpeechRecognitionEngine($culture) -ErrorAction Stop
    $script:voiceEngineId=[string]$recognizer.RecognizerInfo.Id
    $script:voiceCulture=[string]$recognizer.RecognizerInfo.Culture.Name
    $recognizer.SetInputToDefaultAudioDevice()
    $grammar=New-Object System.Speech.Recognition.DictationGrammar -ErrorAction Stop
    $recognizer.LoadGrammar($grammar)
    $recognizer.LoadGrammar((New-FGVoiceExitGrammar $culture))
    Write-VoiceDiagnostic ([pscustomobject]@{state='ready'})
} catch {
    Write-VoiceDiagnostic ([pscustomobject]@{state='initialization_failed';error=$_.Exception.Message})
    if($recognizer){try{$recognizer.Dispose()}catch{}}
    $recognizer=$null
}

if(-not $recognizer){
    Write-Runtime "mic_unavailable" "Voice follow-up could not start. Check the Windows default microphone and installed English (US) speech recognition. Details were saved."
    Start-Sleep -Seconds $voiceOptions.silenceSeconds
    Write-Runtime "idle" "Voice follow-up unavailable. Returning to GSPro." $true
    Restore-GSProFocus
    exit 0
}

Write-Runtime "listening" "Listening for a follow-up. Say 'back to golf' anytime."
$voiceCompletionMessage='Coaching conversation complete. Returning to GSPro.'
try{
while($turn -lt $voiceOptions.maxTurns){
    $heard=Read-FGVoiceTurn $recognizer $voiceOptions {
        param($event)
        Write-VoiceDiagnostic $event
        if($event.state -eq 'retry'){
            Write-Runtime 'listening' ("Speech confidence {0:P0} is below the question threshold {1:P0} (attempt {2} of 3). Speak toward the Windows default microphone, or say back to golf." -f $event.confidence,$voiceOptions.minConfidence,$event.attempt)
        }
    }
    if($heard.action -ne 'question'){
        if($heard.action -eq 'exhausted'){$voiceCompletionMessage='Voice follow-up stopped after three unclear attempts. Check the Windows default microphone. Recognition details were saved. Returning to GSPro.'}
        elseif($heard.action -eq 'error'){$voiceCompletionMessage='Voice recognition stopped with an error. Recognition details were saved. Returning to GSPro.'}
        break
    }
    $q=$heard.text
    $turn++
    Write-Runtime "thinking_followup" ("Heard: "+$q+"  |  Coach is answering.")
    $complex=($q -match "(?i)\b(why|analy|swing|path|spin|tempo|attack|aoa|smash|contact|compare|cause|fix|setup|ball position|stance)\b")
    $model=if($complex){[string]$config.CoachModel}else{[string]$config.FollowupModel}
    $kind=if($complex){"coach"}else{"followup"}
    $context=[ordered]@{coach_card=$coach;local_summary=$summary;recent_conversation=@($history | Select-Object -Last 4);question=$q}
    $followInstructions=@"
You are continuing a voice conversation immediately after coaching one golf-club set in Factor Golf Sim Control Center.
$nameInstruction
$personaInstruction
$coachingLevelInstruction
Answer the question directly at the selected Golfer Experience. Keep it conversational and usually under 90 words.
Do not introduce a new swing fix unless the question requires it. Preserve the one-biggest-issue coaching plan from the current card.
Never invent face angle or face-to-path data. Distinguish reference setup advice from things actually observed.
"@
    try {
        $fa=Invoke-TextModel $model $followInstructions ($context|ConvertTo-Json -Depth 12 -Compress) $kind $false
        $answer=[string]$fa.text
        $history.Add([pscustomobject]@{question=$q;answer=$answer})
        [ordered]@{question=$q;answer=$answer;updated=(Get-Date).ToString("o")} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out "latest_followup.json") -Encoding UTF8
        Write-Runtime "speaking_followup" $answer
        Speak-Natural $answer ("followup"+$turn)
        Write-Runtime "listening" "Listening again. Say 'back to golf' or stay quiet to finish."
    } catch {
        break
    }
}
}finally{try{$recognizer.Dispose()}catch{}}
Write-Runtime "idle" $voiceCompletionMessage $true
Start-Sleep -Milliseconds 500
Restore-GSProFocus
exit 0
