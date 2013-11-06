function Check_OnehopLink ([string] $url, [string] $modelPath)
{
	"Model: $modelPath"
	& .\WrapStarCompiler.cmd $modelPath
	Start-Sleep -Milliseconds 1000
	$jajoinResult = & .\WrapStarJAJoinTool.exe $url | Out-String
	$result = $false
	Write-Host $jajoinResult
	if($jajoinResult -match "the video link is not link to a video")
	{
		$result = $true
	}
	
	return $result
}


$ppeModels = Get-ChildItem D:\v-qichhe\Multimedia\DA\PPEModels | ? {$_.Mode -eq 'd----'}

foreach ($modelfolder in $ppeModels)
{
	"[Check1:]$($modelfolder.fullname)"
	$typeFolders = Get-ChildItem $modelfolder.FullName | ? {$_.Mode -eq 'd----' -and $_.name -notmatch "onehop\w*"}
	foreach ($typefolder in $typeFolders)
	{
		"`t[Check2:]$($typefolder.fullname)"
		$resultFile = Get-ChildItem $typefolder.FullName -Filter '*_result.txt'
		if($resultFile -eq $null)
		{
			continue
		}
		
		if($resultFile -is [Array])
		{
			$resultFile = $resultFile[0]
		}
		
		$resultContent = Get-Content $resultFile.FullName
		$url = ""
		$videoLink = $false
		$nextSite = $false
		
		foreach($line in $resultContent)
		{
			if($line -match "^(http://.+)")
			{
				$url = $matches[1]
			}
			
			if($line -match "/Video/Video.Video.VideoLink")
			{
				$videoLink = $true
			}
			
			if($url -ne "" -and $videoLink -eq $true)
			{
				$flag = Check_OnehopLink $url $modelfolder.fullname
				if($flag -eq $true)
				{
					$modelfolder.Name >> .\"onehoplink.txt"
					write-host "`t[check2:]$flag" -ForegroundColor Red
				}
				$nextSite = $true
				$url = ""
				$videoLink = $false
				break
			}
		}
		
#		$resultContent | foreach {
#			
#			if($_ -match "^(http://.+)")
#			{
#				$url = $matches[1]
#			}
#			
#			if($_ -match "/Video/Video.Video.VideoLink")
#			{
#				$videoLink = $true
#			}
#			
#			if($url -ne "" -and $videoLink -eq $true)
#			{
#				if(Check_OnehopLink $url $modelfolder.fullname)
#				{
#					$modelfolder.Name >> .\"onehoplink.txt"
#					
#				}
#				$nextSite = $true
#				$url = ""
#				$videoLink = $false
#				return
#			}
#		}
		
		#write-host "`t[check2:]$nextSite"
		if($nextSite -eq $true)
		{
			break
		}
		
		# /Video/Video.Video.VideoLink
	}
}