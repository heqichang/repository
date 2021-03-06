function Get-StreamName()
{
    $line = $args[0]
    
    if($line -match "^Stream.+/(.+\.txt)")
    {
        return $($matches[1])
    }
    return ""
}

function Get-StreamLength()
{
    $line = $args[0]
    
    if($line -match "Committed Length.*:.*?(\d+)")
    {
        return $($matches[1])
    }
    return ""
}

function Test-LocalFile()
{
    $file = $args[0]
    $length = [int]$args[1]
    $date = $args[2]
    
    if($length -gt 20MB)
    {
        return $false
    }
    
    if(!(Test-Path "D:\DailyLabel\$date"))
    {
        New-Item D:\DailyLabel\$date -type directory
    }
    
    if(!(Test-Path "D:\DailyLabel\$date\$file"))
    {
        return $true
    }
    
    $item = Get-ChildItem "D:\DailyLabel\$date\$file"
    
    if($item.Length -ne $length)
    {
        return $true
    }
    
    write-host "Skip $file"
    return $false
}

-1..-5 | foreach {
    $date = (Get-Date).AddDays($_).ToString('yyyy-MM-dd')
    $cosmosUrl = "http://cosmos08.osdinfra.net:88/cosmos/mmrepository.prod/local/Prod/Video/Expiry/DailyLabel/$date"

    $cosmosFiles = D:\ScopeSDK\Scope.exe dir $cosmosUrl

    if($lastexitcode -eq -1)
    {
        return
    }

    $fileName = ""
    $length = ""

    foreach($line in $cosmosFiles)
    {
        $tempFileName = Get-StreamName $line
        if(![String]::isnullorempty($tempFileName))
        {
            $fileName = $tempFileName
        }
    
        $tempLength = Get-StreamLength $line
        if(![String]::isnullorempty($tempLength))
        {
            $length = $tempLength
        }
    
        if([String]::isnullorempty($fileName) -or [String]::isnullorempty($length))
        {
            continue
        }
    
        if(Test-LocalFile $fileName $length $date)
        {
            "copy $fileName"
             D:\ScopeSDK\Scope.exe copy "$cosmosUrl/$fileName" "D:\DailyLabel\$date\$fileName" -overwrite
        }
        $fileName = ""
        $length = ""
    }

}




