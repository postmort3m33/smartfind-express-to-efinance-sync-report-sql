# SmartFind Express and eFinance Plus API Sync Discrepancy Report

SQL used for a report formatted for PowerBI that shows discrepancies between the SmartFind and eFinance API sync.

# Features

Uses a Left Join on job number and date to match up with absences that exist and cast NULL for ones that dont

Left Joins to the intergation log table as well using Row_Number to pull the latest integration log per (job,date) 
