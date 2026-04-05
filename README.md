# SmartFind Express and eFinance Plus API Sync Discrepancy Report

SQL used for a report formatted for PowerBI that shows discrepancies between the SmartFind and eFinance API sync.

Reason: This report was made because the SmartFind Express API sync was very inefficient and unstable and there was no easy way inside the SmartFind front end GUI to get this information.

# Features

Uses a Left Join on job number and date to match up SmartFind Express absences that exist in eFinance Plus and cast NULL for ones that dont

Left Joins to the intergation log table as well using the Row Number SQL function to pull the latest integration log per (job,date) 
