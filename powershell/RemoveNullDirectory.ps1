# Call the function with the path of the folder you want to clean up
Param (
    [string]$target
)

function Remove-EmptyFolders {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    # Get all subdirectories
    $subDirectories = Get-ChildItem -Directory $Path

    foreach ($subDirectory in $subDirectories) {
        # Recursively call this function on each subdirectory
        Remove-EmptyFolders -Path $subDirectory.FullName

        # Check if the directory is now empty
        if ((Get-ChildItem -Path $subDirectory.FullName -Force).Count -eq 0) {
            # Remove the empty directory
            Remove-Item -Path $subDirectory.FullName -Force
        }
    }
}

Remove-EmptyFolders -Path $target