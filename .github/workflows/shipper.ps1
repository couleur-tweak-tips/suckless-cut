param(
    [switch]$clean
)

set-location $psscriptroot

if(-not(test-path ./slc-out/)){
    mkdir ./slc-out/
}

$curl = (Get-Command curl -CommandType Application -ErrorAction Stop).Source | Select-Object -Last 1

& $curl --location `
    https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua -o "thumbfast.lua" `
    https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip -o "uosc.zip"

Expand-Archive ./uosc.zip ./slc-out

Move-Item ./thumbfast.lua ./slc-out/scripts/

Copy-Item ./suckless-cut.lua ./slc-out/scripts/

Compress-Archive ./slc-out/* -DestinationPath ./suckless-cut_with-recommended-scripts.zip

if ($clean){
    remove-item ./uosc.zip
    remove-item ./slc-out/ -Recurse -Force
}