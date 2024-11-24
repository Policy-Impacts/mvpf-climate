# Create a new Excel.Application object
$filename = $args[0]
$path = 
$excel = New-Object -ComObject Excel.Application

# Make the application visible
$excel.Visible = $false

# Open an Excel file
$workbook = $excel.Workbooks.Open("${PSScriptRoot}\$filename")

# Save the workbook
$workbook.Save()

# Close the workbook
$workbook.Close()

# Quit Excel
$excel.Quit()

# Release the COM object
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
