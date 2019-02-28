<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER OutputFile
Path to jpeg file. can be ".jpeg" or ".jpg". if file already exist it will append int to the end of the file

.PARAMETER Amount
How many pictures do you want?

.PARAMETER WaitMultiplier
To test out the ratelimit for the site

.EXAMPLE
Get-RandomFace -OutputFile "Path\Picture.jpg"

.NOTES
General notes
#>


function Get-RandomFace {
    [CmdletBinding()]
    param(
        [parameter(HelpMessage="Select Path for outputfile. additional files will have numbers appended to the filename")]
        [System.IO.FileInfo]$OutputFile,

        [ValidateRange(1,999)]
        [Int]$Amount = 1,

        [ValidateRange(0,9)]
        [Int]$WaitMultiplier = 2,

        [ValidateRange(1,999)]
        [int]$ConcurrentCalls = $([int]$env:NUMBER_OF_PROCESSORS+1),

        [switch]$Passthru
    )    

    begin{
        #Check if site is up
        if(!(Test-Connection -Quiet 'https://www.thispersondoesnotexist.com/'))
        {
            Throw "The Source website i use for this content is down :("
        }

        if(!$OutputFile.Directory.Exists)
        {
            Write-verbose "Parent directory does not exsist.. creating"
            new-item -Path $OutputFile.Directory.FullName -ItemType Directory -Force|Out-Null
        }

        write-verbose "Saving images to  $($OutputFile.Directory.FullName)"

        $Extension = $OutputFile.Extension
        $BaseName = $OutputFile.name.Replace($Extension,"")
        if($Extension -notin $(".Jpg",".Jpeg"))
        {
            throw "Outputfile needs to be .Jpeg or .jpg"
        }

        Write-verbose "Directory: $($OutputFile.directory)"

        #Create and open runspace pool, setup runspaces array with min and max threads
        $pool = [RunspaceFactory]::CreateRunspacePool(1, $ConcurrentCalls)
        $pool.ApartmentState = "MTA"
        $pool.Open()
        $runspaces = @()
        

    }

    process {


        #Insert jobs to do in runspaces
        foreach($item in @(0..($Amount-1)))
        {
            #Add Content to Runspace
            $runspace = [PowerShell]::Create()
            [void]$runspace.AddScript({
                param([int]$Seconds)
                start-sleep -Seconds $($Seconds); 
                invoke-webrequest "https://thispersondoesnotexist.com/image" -UseBasicParsing -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.96 Safari/537.36"
            })
            [void]$runspace.AddArgument(($item*$WaitMultiplier))
            $runspace.RunspacePool = $pool
            $runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke();Processed=$false }
        }

        #While there is still items to be processed
        Write-Verbose "Receiving Webcontent and writing to file"
        while ($runspaces.Processed -contains $false) {
            #Get items that are finished running and still not processed
            foreach ($RS in ($runspaces|?{$_.Status.IsCompleted -and !$_.Processed})) {

                # EndInvoke method retrieves the results of the asynchronous call
                $WebResponse = $RS.Pipe.EndInvoke($RS.Status)

                if(!([bool]$WebResponse))
                {
                    throw "Something went wrong.. :(.. i dont have any info of it in this version.. mabye later?"
                }
                #Convert Bitarray to Image
                $Image = $([System.Drawing.Image]::FromStream([System.IO.MemoryStream]::new($WebResponse.content)))
                
                if($Passthru)
                {
                    Write-Output $Image
                }
                else {
                    #Figure out fileame for export. if filename is taken add filename1,filename2 etc untill it find one that doesent exist
                    $TestFile = [System.IO.FileInfo]$OutputFile.FullName
                    $TestInt = 1
                    while($TestFile.exists)
                    {
                        $Newname = "$BaseName$testint$Extension"
                        $Testfile = [System.IO.FileInfo]$(join-path $OutputFile.Directory $Newname)
                        $TestInt++
                    }
    
                    #Save the file
                    Write-verbose "Saving image to $($Testfile.fullname)"
                    $Image.save($Testfile.fullname)
                }

                #Set processed and dispose current RS
                $RS.Processed = $true
                $RS.Pipe.Dispose()
            }
        }
    }
    end{
        #Cleanup
        $pool.Close() 
        $pool.Dispose()
    }

}