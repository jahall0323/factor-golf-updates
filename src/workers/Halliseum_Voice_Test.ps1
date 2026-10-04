param([Parameter(Mandatory=$true)][string]$AppDir,[Parameter(Mandatory=$true)][string]$Voice,[Parameter(Mandatory=$true)][string]$Persona,[string]$CoachingLevel='Rookie',[string]$PlayerName='')
$ErrorActionPreference='SilentlyContinue'
try{Add-Type -AssemblyName PresentationCore}catch{}
try{Add-Type -AssemblyName PresentationFramework}catch{}
$cfgPath=Join-Path $AppDir 'config.json';$defPath=Join-Path $AppDir 'config.default.json';$config=if(Test-Path $cfgPath){Get-Content $cfgPath -Raw|ConvertFrom-Json}else{Get-Content $defPath -Raw|ConvertFrom-Json}
function Get-Key{$p=Join-Path $AppDir 'secrets\openai_api_key.dpapi';if(-not(Test-Path $p)){return $null};try{$sec=ConvertTo-SecureString ((Get-Content $p -Raw).Trim());$b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec);try{return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b)}}catch{return $null}}
$key=Get-Key;if(-not$key){[System.Windows.MessageBox]::Show('Set the OpenAI API key before previewing the coach.','Factor Golf Coach Preview')|Out-Null;exit 2}
$name=$PlayerName.Trim();$prefix=if($name){$name+', '}else{''}

# One underlying swing pattern, taught differently by Golfer Experience and delivered differently by Persona.
$level=[string]$CoachingLevel;if($level -notin @('Rookie','Amateur','Advanced')){$level='Rookie'}
$text=switch($level){
 'Advanced'{
   switch($Persona){
    'Professional / Clean'{"${prefix}your strike pattern is usable, but the head-drift trend is adding low-point variance. Keep the delivery centered and tighten contact before changing path. Give me five more and watch strike dispersion, not one isolated miss."}
    'One of the Boys'{"${prefix}the pattern is playable, but that head drift is moving your low point around. Tighten the strike window before you start screwing with path. Give me five more and judge the pattern, not one ugly ball."}
    'Hood Golf'{"${prefix}look, the delivery ain't bad, but that head drift got your low point movin around too much. Lock the strike window in before we start messin with path. Run five more and judge the pattern, not one janky ball."}
    'Extreme'{"${prefix}the delivery is playable, but your low point is wandering around like a drunk Roomba because of that head drift. Tighten the strike window before touching path. Five more. We are optimizing a pattern, not holding a funeral for one shitty golf ball."}
    default{"${prefix}your pattern is playable, but the head drift is creating low-point variance. Tighten strike consistency before changing path. Give me five more and judge dispersion across the set."}
   }
 }
 'Amateur'{
   switch($Persona){
    'Professional / Clean'{"${prefix}your contact is improving, but your upper body is drifting enough to move the bottom of the swing. That is why strike and carry are still inconsistent. Keep your chest more centered through impact and give me five more before changing anything else."}
    'One of the Boys'{"${prefix}contact is better, but you're drifting enough to move the bottom of the swing around. That's why the strike and carry keep jumping. Stay more centered through impact and give me five more. Don't go rebuilding the whole damn swing."}
    'Hood Golf'{"${prefix}you hittin it cleaner, but you still driftin enough to move the bottom of that swing around. That's why the strike and carry be jumpin. Stay more centered through impact and run five more. We ain't rebuildin the whole damn swing today."}
    'Extreme'{"${prefix}contact is getting its shit together, but your upper body is still wandering enough to move the bottom of the swing. That is why carry is bouncing around. Stay centered and hit five more. Do not remodel the whole house because one cabinet door squeaks."}
    default{"${prefix}contact is improving, but the upper-body drift is moving the bottom of the swing and making strike less repeatable. Stay more centered through impact and give me five more before changing anything else."}
   }
 }
 default{
   switch($Persona){
    'Professional / Clean'{"${prefix}your contact is getting better. Your head is moving during the hit, and that can make the club reach the ground in a different place each swing. For the next five, feel like your head stays quiet while your body turns, then finish balanced on your lead foot."}
    'One of the Boys'{"${prefix}the contact is getting better. Your head is sliding around during the hit, and that makes the bottom of the swing move too. Keep that damn head quieter while you turn, finish balanced on the lead side, and give me five more. One job."}
    'Hood Golf'{"${prefix}you hittin it cleaner now, but your head still slidin around when you strike it. That moves where the club bottoms out, so some shots come out clean and some don't. Next five, keep that head quiet while your body turns and finish balanced on that lead side. One thing at a time."}
    'Extreme'{"${prefix}your contact is finally getting its shit together, but your head is roaming around during impact like it lost its car in a Walmart parking lot. That moves the bottom of the swing. Keep the head quieter, turn through it, finish balanced, and give me five more. That's the whole damn assignment."}
    default{"${prefix}contact is getting better. Your head is moving during the hit, which changes where the club reaches the ground. Keep your head quieter while your body turns, finish balanced on the lead side, and give me five more."}
   }
 }
}
$style=switch($Persona){
 'Professional / Clean'{'Calm, polished PGA coach. Natural, clear and concise. No profanity. Minimal sarcasm.'}
 'One of the Boys'{'Very casual golf buddy and PGA coach. Confident, conversational and playful. Stronger language and light trash talk are okay when they fit. Never robotic or announcer-like.'}
 'Hood Golf'{'Very casual golf buddy and PGA coach using strong natural AAVE-style phrasing, cadence and slang. Confident, playful and direct. Profanity and trash talk are okay when they fit. Keep it readable, never a racial caricature, and never use slurs.'}
 'Extreme'{'Rowdy, vulgar golf buddy and PGA coach with drunk-golf-buddy energy. Heavy profanity, sarcastic delivery, ridiculous real-world analogies and corny dad-joke timing. Stay clear and intelligible, not slurred.'}
 default{'Relaxed golf buddy and PGA coach. Warm, natural and conversational. Light sarcasm and occasional mild profanity when it fits. Never robotic or announcer-like.'}
}
$tmp=Join-Path $env:TEMP ('FactorGolfCoachPreview_'+[guid]::NewGuid().ToString('N')+'.mp3')
try{$headers=@{Authorization='Bearer '+$key};$body=[ordered]@{model=[string]$config.TTSModel;voice=$Voice;input=$text;instructions=$style;response_format='mp3';speed=1.0}|ConvertTo-Json -Compress;$bytes=[Text.Encoding]::UTF8.GetBytes($body);Invoke-WebRequest -Method Post -Uri 'https://api.openai.com/v1/audio/speech' -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bytes -OutFile $tmp -TimeoutSec 120|Out-Null;if(-not(Test-Path $tmp)){throw 'No audio returned'};$p=New-Object System.Windows.Media.MediaPlayer;$p.Open((New-Object Uri $tmp));$deadline=(Get-Date).AddSeconds(5);while(-not$p.NaturalDuration.HasTimeSpan -and(Get-Date)-lt$deadline){Start-Sleep -Milliseconds 100};$sec=8;if($p.NaturalDuration.HasTimeSpan){$sec=[math]::Max(1,$p.NaturalDuration.TimeSpan.TotalSeconds)};$p.Play();Start-Sleep -Milliseconds ([int](($sec+0.4)*1000));$p.Close()}catch{[System.Windows.MessageBox]::Show(('Coach preview failed: '+$_.Exception.Message),'Factor Golf Coach Preview')|Out-Null}finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
