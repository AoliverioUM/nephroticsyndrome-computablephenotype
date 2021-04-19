--Nephrotic Syndrome Computable Phenotype using PCORnet Data
--Build Adjudication Set

--Coded by Chad Dorn at Vanderbilt University Medical Center under the direction of Dr. Michael Matheny
--chad.a.dorn@vumc.org

--Build set of patients for adjudication by pulling 50 patients at 
--random from the patients that were flagged with nephrotic syndrome.
--Then build a set of controls that match the year of encounter for
--the nephrotic syndrome set and match the age (+ or - 5 years) of
--the nephrotic syndrome set.

--Output file name from the current script: Nephrotic_Syndrome_Adjudication_Set.csv
----------------------------------------------------------------------------------------------------------


/*IMPORTANT***********************************************************************************************/
--MODIFY DATABASE NAME in this "use" command to specify your database.
use [ORD_Matheny_201501042D];
GO
/*********************************************************************************************************/


/*IMPORTANT***********************************************************************************************/

--MODIFY SCHEMA PREFIX from "Src." to what is needed to specify your schema.
--In the Vanderbilt database, the "Src" schema is used for the PCOR tables that are used as the source data.

--MODIFY SCHEMA PREFIX from "NS." to what is needed to specify your schema.
--In the Vanderbilt database, the "NS" schema is used for tables that are created during the execution of this script.

--The schema prefix for "Src." and "NS." needs to be changed throughout this ENTIRE SCRIPT.
/*********************************************************************************************************/



--Part 1-------------------------------------------------------------------------------------------------
--Build random sample of nephrotic syndrome cases--

--If random sample table already exists, delete it.
if OBJECT_ID('NS.NS_Random_Sample', 'U') is not NULL
	drop table NS.NS_Random_Sample;


--Build random sample of 50 from nephrotic syndrome cases.
--NOTE: CHANGE "top 50" to another number to adjust the sample size if needed.
select top 50 *
into NS.NS_Random_Sample
from NS.NS_Final_Inclusions
order by NewID();



--Part 2-------------------------------------------------------------------------------------------------
--Build set of possible control cases--

--If table of possible control cases already exists, then delete it.
if OBJECT_ID('NS.NS_Control_Pool', 'U') is not NULL
	drop table NS.NS_Control_Pool;


--Build table of possible control cases
select distinct
	E.PATID
	,YEAR(E.ADMIT_DATE) as Admit_Year
	,(0 + Convert(Char(8),E.ADMIT_DATE,112) - Convert(Char(8),D.BIRTH_DATE,112)) / 10000 AS Age
into NS.NS_Control_Pool
from Src.PCOR_ENCOUNTER as E
	JOIN Src.PCOR_DEMOGRAPHIC as D
		on E.PATID = D.PATID
where
	E.ADMIT_DATE IS NOT NULL
	and (E.Raw_Enc_Type != 'Outpatient visit within inpatient visit' or E.Raw_Enc_Type IS NULL)
;



--Part 3-------------------------------------------------------------------------------------------------
--Combine nephrotic syndrome sample with matching set of possible controls--
--(Based on matching year and age criteria.)

--If combined table already exists, then delete it.
if OBJECT_ID('NS.NS_Plus_Control_Pool', 'U') is not NULL
	drop table NS.NS_Plus_Control_Pool;

--Build table that combines nephrotic syndrome sample with set of matching controls
select 
	NS.PatientID as NS_PatientID
	, NS.Entry_Date as NS_Entry_Date
	, NS.Age AS NS_Age, C.PATID as Control_PatientID
	, C.Admit_Year as Control_Admit_Year
	, C.Age as Control_Age
into NS.NS_Plus_Control_Pool
from NS.NS_Random_Sample as NS
join NS.NS_Control_Pool as C
on C.Admit_Year = Year(NS.Entry_Date) and C.Age between NS.Age - 5 and NS.Age + 5;



--Part 4-------------------------------------------------------------------------------------------------
--Build final set of adjudication cases--

--If adjudication table already exists, then delete it.
if OBJECT_ID('NS.NS_Adjudication_Set', 'U') is not NULL
	drop table NS.NS_Adjudication_Set;


--Insert first row into adjudication set (selected at random)
select top 1 *
into NS.NS_Adjudication_Set
from NS.NS_Plus_Control_Pool
order by NewID();


--Insert remaining rows into adjudication set
--(Selected at random where not already in adjudication set.)
declare @i INT = 0;
declare @total INT = 0;
select @total = Count(*) from NS.NS_Random_Sample

while @i < (@total - 1)
Begin
	Insert into NS.NS_Adjudication_Set
	Select top 1 *
	from NS.NS_Plus_Control_Pool as P
	where P.NS_PatientID not in (Select NS_PatientID from NS.NS_Adjudication_Set)
		and P.Control_PatientID not in (Select Control_PatientID from NS.NS_Adjudication_Set)
	order by NewID()

	set @i = @i+1;
End



--Part 4------------------------------------------------------------------------------------------
--Select desired fields from adjudication set into output table.

if OBJECT_ID('NS.NS_Adjudication_Set_Output', 'U') is not NULL
	drop table NS.NS_Adjudication_Set_Output;

select * 
into 
	NS.NS_Adjudication_Set_Output 
from 
	NS.NS_Adjudication_Set 
order by 
	ns_patientid
	, Control_PatientID;



--Part 5-------------------------------------------------------------------------------------------------
--Generate output file using sqlcmd and the command line--

/*

***** Below, change SERVERNAME, DATABASENAME, PATH for output, and SCHEMA prefix for table name
***** After you change SERVERNAME, DATABASENAME, PATH for output, and SCHEMA prefix for table name, run the command below from the command line:

sqlcmd -S SERVERNAME -d DATABASENAME -E -o "PATH\Nephrotic_Syndrome_Adjudication_Set.csv" -Q "Set NOCOUNT ON; Select * from NS.NS_Adjudication_Set_Output" -W -w 999 -s ","

*/


/***** ALTERNATIVE: If you have the appropriate permissions, you can run the command below from SQL Server instead:
****** Again change SERVERNAME, DATABASENAME, PATH for output, and SCHEMA prefix for table name.*/

Exec xp_cmdshell 'sqlcmd -S SERVERNAME -d DATABASENAME -E -o "PATH\Nephrotic_Syndrome_Adjudication_Set.csv" -Q "Set NOCOUNT ON; Select * from NS.NS_Adjudication_Set_Output" -W -w 999 -s ","'


--END of script---------------------------------------------------------------------------------------------
	 






