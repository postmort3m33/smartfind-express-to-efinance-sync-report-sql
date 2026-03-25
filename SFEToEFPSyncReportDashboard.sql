-- SmartFind Express to eFinance Plus Power BI Dashboard Sync Report Query
-- Created By: Joshua Touchstone (03/24/2026) V2
-- This tool was created because the lack of API efficiency between SmartFind Express and eFinance plus.
-- There are many absences that do not make there way over to eFinance for final record. Many absence changes and updates are lost in transit as well.
--
-- Dependencies:
-- Connected Intelligence/Snowflake Linked Server "<LINKED_SERVER_NAME>" on eFinance Server (Un-hosted)
-- <SFE_INTEGRATION_LOG_TABLE> Filtered eFinance integration error table that only shows SFE data (This is because there can be millios of rows with multi varchar(4000) columns!)
-- eFinance attendance and vacancy tables (Hosted)
--
-- Uses:
-- This query runs on the eFinance database server
-- Lives on the Power BI Report Server in the SmartFind Express Jobs Dashboard - SFEJobs Table
--
-- Notes:
-- Added Latest Integration Response from eFP
--
--
-- First Get Merged eFP Absence Data
DECLARE @StartDate DATETIME = '2025-07-01'; -- First day of SmartFind Express Implementation
WITH FinPlus AS (
	-------------------------------------------------------------------
	-- eFP Attend Table Absences
	-------------------------------------------------------------------
	SELECT
		  sfemask.job_number as JobNumber
		, sfemask.lv_status AS Status
		, a.empl_no as Employee
		, e.l_name AS EmployeeLastName
		, e.f_name AS EmployeeFirstName
		, et.desc_x as EmployeeType
		, RIGHT('000' + CAST(e.base_loc as varchar(3)), 3) as Location
		, pctable.title AS 'Reason'
		, a.pay_code as LeaveCode
		, CONVERT(varchar, a.start_date, 23) as [Date]
		, CAST(a.lv_hrs as decimal(10,2)) as [Days]
		, a.sub_pay_code as SubPayCode
		, a.sub_id as Substitute
		, es.l_name AS 'SubstituteLastName'
		, es.f_name AS 'SubstituteFirstName'
		, a.post_flg AS 'Posted'
	FROM dbo.attend a
	INNER JOIN employee e
		ON e.empl_no = a.empl_no
	LEFT JOIN employee es
		ON es.empl_no = a.sub_id
	INNER JOIN person p
		ON p.empl_no = e.empl_no
	INNER JOIN employee_type et
		ON et.code = p.empl_type
	LEFT JOIN paytable pctable
		ON pctable.pay_code = a.pay_code

	-- join account mask table (There could be two absences per job)
	INNER JOIN sfe_accountmask sfemask
		ON sfemask.row_id = a.row_id

	WHERE a.start_date >= @StartDate

	UNION

	-------------------------------------------------------------------
	-- SFE Vacancy Absence Table
	-------------------------------------------------------------------
	SELECT
		  vac.job_number as JobNumber
		, sfemask.lv_status AS Status
		, NULL AS Employee
		, NULL AS 'Employee First Name'
		, NULL AS 'Employee Last Name'
		, NULL AS EmployeeType
		, RIGHT('000' + CAST(vac.location AS varchar(3)), 3) AS Location
		, 'VACANCY' AS Reason
		, '601' AS LeaveCode
		, CONVERT(varchar, vac.start_date, 23) AS [Date]
		, CAST(vac.sub_hrs AS decimal(10,2)) AS [Days]
		, vac.pay_code AS SubPayCode
		, vac.sub_empl_no AS Substitute
		, emp.l_name AS 'Substitute Last Name'
		, emp.f_name AS 'Substitute First Name'
		, vac.post_flg AS 'Posted'
	FROM sfe_sub_vacancy_table vac
	INNER JOIN employee emp
		ON vac.sub_empl_no = emp.empl_no

	-- join account mask table (There could be two absences per job)
	INNER JOIN sfe_accountmask sfemask
		ON vac.row_id = sfemask.row_id

	WHERE vac.start_date >= @StartDate
),

--
-- Then get the latest integration log response from the table
LatestLog AS (
		SELECT [Time Stamp]
			  ,[Job Number]
			  ,[Absence Date]
			  ,[Response]
		FROM (
			SELECT [Time Stamp]
				  ,[Job Number]
				  ,[Absence Date]
				  ,[Response]
				  ,ROW_NUMBER() OVER (
					  PARTITION BY [Job Number], [Absence Date]
					  ORDER BY [Time Stamp] DESC
				  ) AS rn
			FROM [<SFE_INTEGRATION_LOG_TABLE>] -- Filtered SFE Integration Log Table
		) ranked
		WHERE rn = 1
)

--
--
-- Now Join it to the SFE Data on Job Number and Date Composite Key
SELECT
    jobd.[JOBID] AS [JobNumber],
    code.[DESCR] AS [SFEStatus],
	efp.Status AS [eFPStatus],
    codef.[DESCR] AS [FillStatus],
    CASE
        WHEN jobd.[VERIFIEDBY] = '0' THEN 'No'
        ELSE 'Yes'
    END AS [Verified],
    cn.[DESCR] AS [Classification],
    rn.[DESCR] AS [Reason],
    CAST(jobd.[ABSENCESTARTDTTM] as date) AS [JobStart],
    empper.[ACCESSCD] AS [Employee],
    subper.[ACCESSCD] AS [Substitute],
	CASE
		WHEN efp.Posted = 'P' THEN 'True'
		WHEN efp.Posted = 'U' THEN 'False'
		ELSE NULL
	END AS [Posted],
	logs.Response AS [Latest eFP Response]
	
-- Tables
FROM [<SFE Database>].[JOBDETAIL] jobd -- Job Detail Table has a New row Per Job Per Day

LEFT JOIN [<SFE Database>].[JOB] job -- Job Table to get the Employee Number from/0 if its a vacancy
    ON job.[JOBID] = jobd.[JOBID]

LEFT JOIN [<SFE Database>].[PERSON] empper -- Employee PERSON lookup via JOB table
    ON empper.[PERSONID] = job.[EMPLOYEEID]

LEFT JOIN [<SFE Database>].[PERSON] subper -- Substitute PERSON lookup via JOBDETAIL (Assigned Sub)
    ON subper.[PERSONID] = jobd.[ASSIGNEDSUBID]

LEFT JOIN [<SFE Database>].[CODE] code -- Code Mapper For Job Status
    ON jobd.[JOBSTATUS] = code.[CODENUM]
   AND code.[CODETYPE] = '8' -- Job Status Codes
   AND code.[LANGCD] = '1' -- English Filter

LEFT JOIN [<SFE Database>].[CODE] codef -- Code Mapper for Fill Status
    ON codef.[CODENUM] = jobd.[FILLSTATUS]
   AND codef.[CODETYPE] = '7'
   AND codef.[LANGCD] = '1'

LEFT JOIN <SFE Database>].[REASONNAME] rn -- Reason ID to Name Mapper
    ON jobd.[REASONID] = rn.[ID]

LEFT JOIN [<SFE Database>].[CLASSNAME] cn -- Classification ID to Name Mapper
    ON jobd.[CLASSFID] = cn.[ID]

LEFT JOIN FinPlus efp -- Join on existing eFinance Absences with key (Job, Date)
	ON efp.JobNumber = jobd.[JOBID]
	AND CAST(efp.Date AS Date) = CAST(jobd.[ABSENCESTARTDTTM] as Date)

-- Add to Log CTE
LEFT JOIN LatestLog logs
	ON logs.[Job Number] = jobd.[JOBID]
	AND logs.[Absence Date] = TRY_CONVERT(date, jobd.[ABSENCESTARTDTTM])