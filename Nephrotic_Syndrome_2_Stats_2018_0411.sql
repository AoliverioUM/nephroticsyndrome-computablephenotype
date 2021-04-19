--Nephrotic Syndrome Computable Phenotype using PCORnet Data
--Descriptive Statistics

--Coded by Chad Dorn at Vanderbilt University Medical Center under the direction of Dr. Michael Matheny
--chad.a.dorn@vumc.org

----------------------------------------------------------------------------------------------------------
--This script generates descriptive statistics for the set of patients identified as positive for 
--nephrotic syndrome as compared to the overall population.

--Output file name: Nephrotic_Syndrome_Stats.csv
----------------------------------------------------------------------------------------------------------


/*IMPORTANT***********************************************************************************************/
--MODIFY DATABASE NAME in this "use" command to specify your database.
use ORD_Matheny_201501042D;
GO
/*********************************************************************************************************/


/*IMPORTANT***********************************************************************************************/

--MODIFY SCHEMA PREFIX from "Src." to what is needed to specify your schema.
--In the Vanderbilt database, the "Src" schema is used for the PCOR tables that are used as the source data.

--MODIFY SCHEMA PREFIX from "NS." to what is needed to specify your schema.
--In the Vanderbilt database, the "NS" schema is used for tables that are created during the execution of this script.

--The schema prefix for "Src." and "NS." needs to be changed throughout this ENTIRE SCRIPT.
/*********************************************************************************************************/


--Part 1---------------------------------------------------------------------------------------
--Join NS result set with full set of patients


 select 
	  D.patid
	, Max(Demo.HISPANIC) as HISPANIC
	, Max(Demo.RACE) as RACE
	, Max(Demo.SEX) as SEX
	, Max(Demo.RAW_HISPANIC) as RAW_HISPANIC
	, Max(Demo.RAW_RACE) as RAW_RACE
	, Max(Demo.RAW_SEX) as RAW_SEX
	, Max(Demo.BIRTH_DATE) as BIRTH_DATE
	,(0 + Convert(Char(8),Max(D.ADMIT_DATE),112) - Convert(Char(8),Max(Demo.BIRTH_DATE),112)) / 10000 AS Age
	,case
		when FI.PatientID is not null then 1 else 0 
	 end as NS_Flag
into NS.NS_Stat_Records_All
from SRC.PCOR_DIAGNOSIS as D
	join SRC.PCOR_DEMOGRAPHIC as Demo
		on D.PATID = Demo.PATID
	left join NS.NS_Final_Inclusions AS FI
		on D.PATID = FI.PatientID
 group by D.PATID, FI.PatientID
 ;

 
 --Part 2----------------------------------------------------------------------------------------
 --Assign demographic categories


if OBJECT_ID('NS.NS_Stat_Records', 'U') is not NULL
	drop table NS.NS_Stat_Records;

 select
	E.patid as PatientID
	, case
		when Min(E.Age) is null then 999
		else Min(E.Age) 
	end as Age
	, case
		when Min(E.Age) is null then 'Unknown'
		when MIN(E.age) < 20 then '0-19'
		when MIN(E.age) >=20 and  MIN(E.age) < 30 then '20-29'
		when MIN(E.age) >=30 and  MIN(E.age) < 40 then '30-39'
		when MIN(E.age) >=40 and  MIN(E.age) < 50 then '40-49'
		when MIN(E.age) >=50 and  MIN(E.age) < 60 then '50-59'
		when MIN(E.age) >=60 and  MIN(E.age) < 70 then '60-69'
		when MIN(E.age) >=70 and  MIN(E.age) < 80 then '70-79'
		when MIN(E.age) >=80 and  MIN(E.age) < 120 then '80-119'
		else 'Unknown'
	end as Age_Group
	, case
		when Min(E.Sex) is null then 'Unknown'
		when Min(E.Sex) = 'F' then 'Female'
		when Min(E.Sex) = 'M' then 'Male'
		else 'Unknown'
	end as Sex
	, case
		when Min(E.Race) is null then 'Unknown'
		else Min(E.Race)
	end as Race
	, case
		when Min(E.Hispanic) is null then 'Unknown'
		else Min(E.Hispanic)
	end as Hispanic
	, E.NS_Flag
 into NS.NS_Stat_Records
 from NS.NS_Stat_Records_All as E
 group by E.patid, E.NS_Flag
 ;


--Part 3------------------------------------------------------------------------------------
--Create table to hold results--------------------------------------------------------

if OBJECT_ID('#NS_Stats1', 'U') is not NULL
	drop table #NS_Stats1;

CREATE TABLE #NS_Stats1
(
	Category [nvarchar](20) NULL,
	Subcategory [nvarchar](20) NULL,
	Overall_Quantity [numeric] NULL,
	NS_Quantity [numeric] NULL
);



--Part 4-------------------------------------------------------------------------------
--Insert Totals into results table-----------------------------------------------

insert into #NS_Stats1
select 
	'Total' as Category
	,'Total' as Subcategory
	, count(*) as Overall_Quantity
	, sum(NS_Flag) as NS_Quantity
from NS.NS_Stat_Records
;


--Part 5-------------------------------------------------------------------------------
--Insert Sex into results table--------------------------------------------------

insert into #NS_Stats1
select 
	'Sex' as Category
	,Sex as Subcategory
	, count(*) as Overall_Quantity
	, sum(NS_Flag) as NS_Quantity
from NS.NS_Stat_Records
group by Sex
order by Sex
;


--Part 6-------------------------------------------------------------------------------
--Insert race into results table--------------------------------------------------

insert into #NS_Stats1
select 
	'Race' as Category
	,case
		when Race = '01' then 'American Indian'
		when Race = '02' then 'Asian'
		when Race = '03' then 'African American'
		when Race = '04' then 'Pacific Islander'
		when Race = '05' then 'White'
		when Race = '06' then 'Multiple Race'
		else 'Unknown'
	end as Subcategory
	, count(*) as Overall_Quantity
	, sum(NS_Flag) as NS_Quantity
from NS.NS_Stat_Records
group by Race
order by Race
;


--Part 7-------------------------------------------------------------------------------
--Insert ethnicity into results table--------------------------------------------

insert into #NS_Stats1
select 
	'Hispanic' as Category
	,case
		when Hispanic = 'N' then 'No'
		when Hispanic = 'Y' then 'Yes'
		else 'Unknown'
	end as Subcategory
	, count(*) as Overall_Quantity
	, sum(NS_Flag) as NS_Quantity
from NS.NS_Stat_Records
group by Hispanic
order by Hispanic
;



--Part 8-------------------------------------------------------------------------------
--Insert age groups into results table-------------------------------------------


--Age Groups
insert into #NS_Stats1
select 
	'Age_Group' as Category
	, Age_Group as Subcategory
	, count(*) as Overall_Quantity
	, sum(NS_Flag) as NS_Quantity
from NS.NS_Stat_Records
group by Age_Group
order by Age_Group
;


--Part 9-------------------------------------------------------------------------------
--Insert age stats into results table--------------------------------------------

if OBJECT_ID('#NS_Stat_Age', 'U') is not NULL
	drop table #NS_Stat_Age;

CREATE TABLE #NS_Stat_Age
(
	Data_Group [nvarchar](20) NULL,
	Category [nvarchar](20) NULL,
	Age_Min [numeric] NULL,
	Age_Max [numeric] NULL,
	Age_Mean [numeric] NULL,
	Age_StDev [numeric] NULL,
	Age_Median [numeric] NULL,
	Age_Mode [numeric] NULL,
);


--Overall Aggregates
insert into #NS_Stat_Age
select
	'Overall_Quantity' AS Data_Group
	,'Age_Stat' AS Category
	,min(age) as Age_Min
	,max(age) as Age_Max
	,avg(age) as Age_Mean
	,stdevp(age) as Age_StDev
	,0 as Age_Median
	,0 as Age_Mode
from NS.NS_Stat_Records
where age < 120 and age is not null
;

--Overall Median
declare @Overall_Total int;
select @Overall_Total = Overall_Quantity
from #NS_Stats1 where Category = 'Total'
;

insert into #NS_Stat_Age
SELECT 
	'Overall_Quantity' AS Data_Group
	,'Age_Stat' AS Category
	,0 as Age_Min
	,0 as Age_Max
	,0 as Age_Mean
	,0 as Age_StDev
	,age as Age_Median
	,0 as Age_Mode
FROM NS.NS_Stat_Records 
ORDER BY age
OFFSET (@Overall_Total/2) rows
fetch next 1 rows only;

--Overall Mode
insert into #NS_Stat_Age
SELECT top 1
	'Overall_Quantity' AS Data_Group
	,'Age_Stat' AS Category
	,0 as Age_Min
	,0 as Age_Max
	,0 as Age_Mean
	,0 as Age_StDev
	,0 as Age_Median
    ,age as Age_Mode
FROM NS.NS_Stat_Records
GROUP BY age
ORDER BY count(*) DESC
;


--NS Aggregates
insert into #NS_Stat_Age
select
	'NS_Quantity' AS Data_Group
	,'Age_Stat' AS Category
	,min(age) as Age_Min
	,max(age) as Age_Max
	,avg(age) as Age_Mean
	,stdevp(age) as Age_StDev
	,0 as Age_Median
	,0 as Age_Mode
from NS.NS_Stat_Records
where age < 120 and age is not null and NS_Flag = 1
;

--NS Median
declare @NS_Total int;
select @NS_Total = NS_Quantity
from #NS_Stats1 where Category = 'Total'
;

insert into #NS_Stat_Age
SELECT 
	'NS_Quantity' AS Data_Group
	,'Age_Stat' AS Category
	,0 as Age_Min
	,0 as Age_Max
	,0 as Age_Mean
	,0 as Age_StDev
	,age as Age_Median
	,0 as Age_Mode
FROM NS.NS_Stat_Records
where age < 120 and age is not null and NS_Flag = 1
ORDER BY age
OFFSET (@NS_Total/2) rows
fetch next 1 rows only;

--NS Mode
insert into #NS_Stat_Age
SELECT top 1
	'NS_Quantity' AS Data_Group
	,'Age_Stat' AS Category
	,0 as Age_Min
	,0 as Age_Max
	,0 as Age_Mean
	,0 as Age_StDev
	,0 as Age_Median
    ,age as Age_Mode
FROM NS.NS_Stat_Records
where age < 120 and age is not null and NS_Flag = 1
GROUP BY age
ORDER BY count(*) DESC
;

select 
	Data_Group
	, Category
	, max(Age_Min) as Age_Min
	, max(Age_Max) as Age_Max
	, max(Age_Mean) as Age_Mean
	, max(Age_StDev) as Age_StDev
	, max(Age_Median) as Age_Median
	, max(Age_Mode) as Age_Mode
into #NS_Stat_Age_Group
from #NS_Stat_Age
group by 
	Data_Group
	, Category
;


--Unpivot Age Stats
select Category, Data_Group, Subcategory, StatValue into #NS_Stat_Age_Unpivot 
from (select Category, Data_Group, Age_Min, Age_Max, Age_Mean, Age_StDev, Age_Median, Age_Mode from #NS_Stat_Age_Group) as AgeData
UNPIVOT
(StatValue
for Subcategory IN (Age_Min, Age_Max, Age_Mean, Age_StDev, Age_Median, Age_Mode)) as #Unpivot_Tbl
order by category, data_group
;


--Pivot Age Quantities
select Category, Subcategory, Overall_Quantity, NS_Quantity into #NS_Stat_Age_Pivot 
from (select Category, Data_Group, Subcategory, StatValue from #NS_Stat_Age_Unpivot) as AgeData
PIVOT
(max(StatValue)
for Data_Group IN (Overall_Quantity, NS_Quantity)) as #Pivot_Tbl
order by Category, Subcategory
;


insert into #NS_Stats1
select * from #NS_Stat_Age_Pivot
;


--Part 10---------------------------------------------------------------------------------------------------
--Build final table----------------------------------------------------------------------------------


if OBJECT_ID('NS.NS_Stats', 'U') is not NULL
	drop table NS.NS_Stats;

select *
	,case
		when Overall_Quantity != 0 and Category != 'Age_Stat' then (NS_Quantity/Overall_Quantity)
		else 0 
	 end as 'NS/Overall'
	,case
		when @Overall_Total != 0 and Category != 'Age_Stat' then(Overall_Quantity/@Overall_Total)
		else 0 
	 end as 'Overall/Total'
	 ,case
		when @NS_Total != 0 and Category != 'Age_Stat' then(NS_Quantity/@NS_Total)
		else 0 
	 end as 'NS/NS Total'
into NS.NS_Stats
from #NS_Stats1
order by category, subcategory;


--Part 11------------------------------------------------------------------------------------------
--Select desired stat results into output table----------------------------------------------------

select *
into NS.NS_Stats_Output
from NS.NS_Stats
order by category, subcategory;


--Part 12-----------------------------------------------------------------------------------------
--Generate output file----------------------------------------------------------------------------

/*

***** Below, change SERVERNAME, DATABASENAME, PATH for output, and SCHEMA prefix for table name
***** After you change SERVERNAME, DATABASENAME, PATH for output, and SCHEMA prefix for table name, run the command below from the command line:

sqlcmd -S SERVERNAME -d DATABASENAME -E -o "PATH\Nephrotic_Syndrome_Stats.csv" -Q "Set NOCOUNT ON; Select * from NS.NS_Stats_Output" -W -w 999 -s","

*/


/***** ALTERNATIVE: If you have the appropriate permissions, you can run the command below from SQL Server instead:
****** Again change SERVERNAME, DATABASENAME, PATH for output, and SCHEMA prefix for table name.*/

Exec xp_cmdshell 'sqlcmd -S SERVERNAME -d DATABASENAME -E -o "PATH\Nephrotic_Syndrome_Stats.csv" -Q "Set NOCOUNT ON; Select * from NS.NS_Stats_Output" -W -w 999 -s","'


--END of script---------------------------------------------------------------------------------------------

