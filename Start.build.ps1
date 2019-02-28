$Build = @{
    Module = @{
        Version = "0.1.$(get-date -Format "yy.MM.dd")"
    }
}

Invoke-Pester

ipmo .\With.RandomFace.psm1

