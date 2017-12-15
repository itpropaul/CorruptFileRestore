<# Inserts the contents of the folder provided by the user into a variable named $problemFolder, which becomes an array
of objects. #>
$problemFolder = Read-Host "Enter Folder that contains corrupted files. Wildcards are allowed for directory placeholders. For example, 'C:\*\*' would look for files in the subdirectories of 'C:\' and no further."

<# Pipes all of the contents within $problemFolder to Get-FileHash. Whenever Get-FileHash fails to process a file it
throws an error. I use the "ErrorVariable" parameter to capture all of the errors that I want to act on inside a
variable which then becomes an array of objects, named $err. #>
Get-ChildItem $problemFolder |Get-FileHash -ErrorVariable err

"`n##################################################################################################################`n"

# Iterates through each object in the $err variable.
foreach ($errorRecord in $err)
{
    <# Whenever Get-FileHash fails to process a file, it actually throws 4 individual errors. Since I only want to
    process each corrupt file one time I need a way to filter out only one relevant error message for each file.
    Originally I only had the one if statement that looks at the Exception.Message property, but one of the errors
    didn't even include the Exception class, which threw a whole new set of errors. So this if statement includes
    only "ErrorRecord" type errors. The others that didn't include an Exception class were "MethodInvocationException"
    errors. #>
    if ($errorRecord.GetType().Name.Equals("ErrorRecord") -eq "True")
    {
        <# This if statement includes only errors that contain the word "corrupt". This keeps the program scrictly
        focused on repairing corrupt files and eliminates non-corrupt files from getting processed. #>
        if ($errorRecord.Exception.Message.contains("corrupt") -eq "True")
        {
            # Filters out the other two error messages associated with corrupt files that don't contain the filepath.
            if ($errorRecord.CategoryInfo.TargetName.contains("\\"))
            {
                $corruptFile = $errorRecord.CategoryInfo.TargetName
                $corruptFileRestoreSource = $corruptFile.Replace("CorruptFileServer", "GoodFileServer")
                # Attempts to overwrite the corrupt file with a good one. Errors get redirected to a log file.
                Copy-Item $corruptFileRestoreSource $corruptFile 2>> "C:\LogFolder\FailedRestores.txt"
                # If the Copy-Item operation succeeds, then it gets printed to screen and logged (Tee-Object).
                <# A note about $? - "$? applies to all command execution. It indicates success for the previous most
                command. Note that non-terminating errors (Get-ChildItem idontexist) still result in a $? returning true.
                If a command throws a terminating error then $? returns $false. If necessary you can force a command to
                convert a non-terminating error into a terminating error by using the ubiquitous parameter -ErrorAction
                Stop" -Keith Hill here https://goo.gl/MH2oPV #>
                if ($? -eq 'True')
                {
                    "$corruptFileRestoreSource replaced $corruptFile" |Tee-Object -FilePath "C:\LogFolder\SuccessfulRestores.txt" -Append
                }
            }
        }
    }
}

# After the main script finished, I used notepad++ to get just the filename paths in the failure log. In the case of permission denied errors, I used the following script:
# I could have just as easily used copy-item with the force flag instead of xcopy with the r flag.
# foreach ($badfile in Get-Content "C:\LogFolder\FailedRestores.txt"){xcopy $badfile.replace("CorruptFileServer", "GoodFileServer") $badfile /y /r}
