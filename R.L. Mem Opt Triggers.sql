use Project5;
go




--mem.opt.RTDInterval trigger---

CREATE TRIGGER dbo.INSERT_RTDInterval ON [dbo].[RTDIndicativeLMP]
    WITH NATIVE_COMPILATION,SCHEMABINDING  

AFTER INSERT
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    ) 
	
INSERT INTO dbo.RTDInterval (IntervalID,
					RTDTimestamp,
					IntervalEnding, 
					IntervalRepeatedHourFlag,
					RepeatedHourFlag)
SELECT DISTINCT  [IntervalId]
				,[RTDTimestamp],
				[IntervalEnding],
				[IntervalRepeatedHourFlag],
				[RepeatedHourFlag]
				
    
FROM inserted
where not EXISTS (select IntervalID FROM dbo.RTDInterval where  RTDTimestamp =  inserted.[RTDTimestamp]
               and IntervalEnding = inserted.[IntervalEnding] )
end
GO

 ---mem.opt.SettlementPointtype--

CREATE TRIGGER dbo.INSERT_Set_Pnt_Type ON [dbo].[RTDIndicativeLMP]
 WITH NATIVE_COMPILATION,SCHEMABINDING  

AFTER INSERT, UPDATE 
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    ) 
INSERT INTO dbo.SettlementPointType (SettlementPointType)
SELECT DISTINCT ([SettlementPointType]) FROM inserted
where not exists (select  SettlementPointType from dbo.SettlementPointType where  SettlementPointType = inserted.[SettlementPointType])

END
GO

---MEM.OPT.SettlementPoint trigger----
CREATE TRIGGER dbo.INSERT_Set_Point ON [dbo].[RTDIndicativeLMP]
 WITH NATIVE_COMPILATION,SCHEMABINDING  
AFTER INSERT, UPDATE 
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    ) 
INSERT INTO dbo. SettlementPoint (SettlementPoint, SettlementPointTypeID)
									
SELECT distinct [SettlementPoint],SettlementPointTypeID FROM inserted 
JOIN dbo.SettlementPointType pt on inserted.[SettlementPointType] = pt.SettlementPointType 
WHERE  not EXISTS (SELECT SettlementPoint FROM dbo. SettlementPoint WHERE SettlementPoint =  inserted.[SettlementPoint])

END
GO

--mem.opt.Settlement trigger---

CREATE TRIGGER dbo.INSERT_Settlement ON [dbo].[RTDIndicativeLMP]
 WITH NATIVE_COMPILATION,SCHEMABINDING  
AFTER INSERT, UPDATE 
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    ) 

INSERT dbo.Settlement ( TimestampID, IntervalID,
						SettlementPointID,
								LMP)


SELECT rtd.TimestampID, rtd.IntervalID ,SP.SettlementPointID, [LMP]
from inserted
JOIN dbo.SettlementPoint SP
ON inserted.[SettlementPoint]=SP.SettlementPoint
JOIN [dbo].[RTDInterval] rtd ON inserted.[IntervalId]=rtd.[IntervalID]
where inserted.rtdtimestamp = rtd.rtdtimestamp

END
GO

-- mem.optim.SettlementPointTypeCombo

CREATE TRIGGER dbo.INSERT_Set_PointT_Combo ON dbo.Settlement
 WITH NATIVE_COMPILATION,SCHEMABINDING  
AFTER INSERT, UPDATE 
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    ) 

INSERT dbo.SetPoint_TypeCombo  ( [SettlementID],IntervalID, SettlementPointTypeCombo )

   SELECT  inserted.[SettlementID],inserted.IntervalID, sp.SettlementPoint+'_'+'['+spt.SettlementPointType+']' AS SettelmentPointTypeCombo
   FROM inserted
	join [dbo].[SettlementPoint] sp on inserted.[SettlementPointID] = sp.[SettlementPointID]
	 join [dbo].[SettlementPointType] spt ON sp.[SettlementPointTypeID] = spt.[SettlementPointTypeID]
  WHERE not exists (select[ComboID],[SettlementID],[IntervalID],[SettlementPointTypeCombo] 
  from dbo.SetPoint_TypeCombo  where SettlementID = inserted.SettlementID)

END
GO

--- mem. opt. REMOVE DATA FROM [dbo].[RTDIndicativeLMP] trigger ---

CREATE TRIGGER [dbo].REMOVEOLDDATA ON [dbo].[RTDIndicativeLMP]

 WITH NATIVE_COMPILATION,SCHEMABINDING  
AFTER INSERT
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    ) 

    DELETE 
    FROM [dbo].[RTDIndicativeLMP] 
    
END
go


----PIVOT---

CREATE TRIGGER dbo.INSERT_Pivottbl ON [dbo].[RTDIndicativeLMP]
 WITH NATIVE_COMPILATION,SCHEMABINDING  
AFTER INSERT, UPDATE 
AS
BEGIN ATOMIC WITH  		
   (  
    TRANSACTION ISOLATION LEVEL = SNAPSHOT,  
    LANGUAGE = N'us_english'  
    )  

	SELECT  * 
INTO   PivotTable  
FROM   PivotView

 DECLARE @colSQL VARCHAR(MAX) 
   SELECT  @colSQL = STUFF((SELECT DISTINCT ','+QUOTENAME(SettlementPointTypeCombo)
          FROM dbo.SetPoint_TypeCombo 
          FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)') 
    ,1,1,'')
   PRINT @colSQL
   
	DECLARE @pvtSQL NVARCHAR(MAX)
SET @pvtSQL = '
SELECT * FROM
(	SELECT stl.[IntervalID], sj.SettlementPointTypeCombo ,rtd.[RTDTimestamp],rtd.[IntervalEnding],
rtd.[RepeatedHourFlag], rtd.[IntervalRepeatedHourFlag], stl.[LMP] 
From [dbo].[RTDInterval]rtd
join [dbo].[Settlement]stl on rtd.[IntervalID]=stl.[IntervalID]
join [dbo].[SettlementPoint]sp on sp.[SettlementPointID] = stl.[SettlementPointID]
join [dbo].[SettlementPointType]spt on sp.[SettlementPointTypeID] = spt.[SettlementPointTypeID]
join [dbo].[SetPoint_TypeCombo ] sj on stl.[SettlementID] = sj.[SettlementID] 
   ) pivotdata

PIVOT

( MAX ([LMP]) for SettlementPointTypeCombo IN (' + @colSQL + ')) pivotresult

Order by IntervalID ' 

EXECUTE (@pvtSQL)
 



SELECT* FROM PivotView
ORDER BY IntervalId


