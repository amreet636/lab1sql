
USE [master]
GO

if exists 
(
	select	* 
	from	sysdatabases 
	where name='aaulakh2_Lab1'
)
		drop database aaulakh2_Lab1
go

CREATE DATABASE [aaulakh2_Lab1]
GO

USE [aaulakh2_Lab1]
GO


-- generating tables
CREATE TABLE [dbo].[Class]
(
	[ClassID] nvarchar (50) not null,
	[ClassDescription] nvarchar (50) null,
	CONSTRAINT [PK_Class_ClassID] PRIMARY KEY ([ClassID])
)
GO

ALTER TABLE Class ADD CONSTRAINT CHK_CLASSDESCRIPTION_LENGTH CHECK (len([CLASSDESCRIPTION]) > 2)
GO

CREATE TABLE [dbo].[Riders]
(
	[RiderID] int IDENTITY (10, 1) not null
		CONSTRAINT [PK_Riders_RiderID] PRIMARY KEY,
	[Name] nvarchar (50) not null
		CONSTRAINT CHK_Name_Length CHECK (len([Name]) > 4),
	[ClassID] nvarchar (50) null,
	CONSTRAINT FK_Riders_ClassID FOREIGN KEY ([ClassID])
	REFERENCES Class(ClassID) ON DELETE NO ACTION
)
GO

CREATE TABLE [dbo].[Bikes]
(
	[BikeID] nvarchar (6) not null
		CONSTRAINT CHK_BikeID_Format CHECK ([BikeID] like '[0][0-1][0-9][HYS]-[AP]'),
	[StableDate] datetime null
		CONSTRAINT Default_StableDate default getdate(),
	CONSTRAINT PK_Bikes_BikedID PRIMARY KEY ([BikeID])
)
GO

CREATE TABLE [dbo].[Sessions]
(
	[RiderID] int not null,
	[BikeID] nvarchar (6) not null,
	[SessionDate] datetime not null
		CONSTRAINT CHK_SessionsDate CHECK ([SessionDate] > '1 Sep 2017'),
	[Laps] int null
		CONSTRAINT Default_Laps default 0,
	CONSTRAINT PK_Sessions_RiderID_BikeID_SessionDate PRIMARY KEY ([RiderID], [BikeID], [SessionDate]),
	CONSTRAINT FK_Session_RiderID FOREIGN KEY ([RiderID])
	REFERENCES Riders(RiderID) ON DELETE NO ACTION
)

GO

CREATE NONCLUSTERED INDEX NCI_RiderID_SessionDate ON [Sessions] (RiderID, SessionDate)
GO

ALTER TABLE [Sessions] ADD CONSTRAINT FK_Sessions_BikeID FOREIGN KEY (BikeID)
						 REFERENCES Bikes(BikeID) ON DELETE NO ACTION
GO

-- Poopulate Class
INSERT INTO aaulakh2_Lab1.dbo.Class(ClassID, ClassDescription)
	values ('moto_3', 'Default Chassis, 250cc'),
		   ('moto_2', 'Default 600cc, Custom Chassis'),
		   ('motogp', '1000cc Factory Spec')
GO
-- Procedures

--PopulateBikes
if exists
(
	select *
	from sysobjects
	where name like 'PopulateBikes'
)

	drop procedure PopulateBikes
GO

create procedure PopulateBikes
as
	declare @FirstDigit int = 0
	declare @SecondDigit int = 0
	while @FirstDigit < 2
		BEGIN
			while @SecondDigit < 10
				BEGIN
					INSERT INTO aaulakh2_Lab1.dbo.Bikes(BikeID, StableDate)
					values(Cast('0' as varchar(2))+Cast(@FirstDigit as  varchar(1))+Cast(@SecondDigit as varchar(1))+'H-A', getdate()),
						  (Cast('0' as varchar(2))+Cast(@FirstDigit as  varchar(1))+Cast(@SecondDigit as varchar(1))+'H-P', getdate()),
						  (Cast('0' as varchar(2))+Cast(@FirstDigit as  varchar(1))+Cast(@SecondDigit as varchar(1))+'Y-A', getdate()),
						  (Cast('0' as varchar(2))+Cast(@FirstDigit as  varchar(1))+Cast(@SecondDigit as varchar(1))+'Y-P', getdate()),
						  (Cast('0' as varchar(2))+Cast(@FirstDigit as  varchar(1))+Cast(@SecondDigit as varchar(1))+'S-A', getdate()),
						  (Cast('0' as varchar(2))+Cast(@FirstDigit as  varchar(1))+Cast(@SecondDigit as varchar(1))+'S-P', getdate())
					set @SecondDigit = @SecondDigit + 1
				END
			set @FirstDigit = @FirstDigit + 1
			set @SecondDigit = 0
		END

GO

exec PopulateBikes
GO


Select *
from Bikes
GO

-- Add Rider Stored Procedure
if exists
(
	select *
	from sysobjects
	where name like 'AddRider'
)

	drop procedure AddRider
GO

create procedure AddRider
@Name as nvarchar(50),
@ClassID as nvarchar(50),
@ErrorMessage as varchar(50) output
as
	if (@Name is null or @Name like '')
	begin
		set @ErrorMessage = 'Add Rider: Name is null or empty'
		return -1
	end
	if not exists (select * from Class where ClassID like @ClassID)
	begin
		set @ErrorMessage = 'Add Rider: Class does not exist'
		return -1
	end

	INSERT INTO aaulakh2_Lab1.dbo.Riders(Name, ClassID)
	values(@Name, @ClassID)

	set @ErrorMessage = 'OK'
	return 0
GO


-- Remove Rider Stored Procedure
if exists
(
	select *
	from sysobjects
	where name like 'RemoveRider'
)

	drop procedure RemoveRider
GO

-- Add Rider Test End

-- Remove Rider Stored Procedure
create procedure RemoveRider
	@RiderID as int,
	@Force as bit = 0,
	@ErrorMessage as nvarchar(max) output
as
	if (@RiderID is null)
	begin
		set @ErrorMessage = 'Remove Rider: Rider ID is null'
		return -1
	end

	if not exists (select * from Riders where RiderID = @RiderID)
	begin
		set @ErrorMessage = 'Remove Rider: ' + Cast(@RiderID as nvarchar) + ' does not exist'
	end

	if (@Force = 1)
	begin 
		if exists ( select * from Sessions where RiderID = @RiderID)
		begin
			delete Sessions  
			where RiderID like
			(
				select RiderID
				from Riders
				where RiderID = @RiderID
			)
			
		end
	end

	if (@Force = 0)
	begin
		if exists ( select * from Sessions where RiderID = @RiderID)
		begin
			set @ErrorMessage = 'Remove Rider: Force set to false, Session Exists'
			return -1
		end
	end

	delete Riders where RiderID = @RiderID
	set @ErrorMessage = 'OK'
	return 0
GO




-- Add Session Stored Procedure
if exists
(
	select *
	from sysobjects
	where name like 'AddSession'
)

	drop procedure AddSession
GO

create procedure AddSession
	@RiderID as int,
	@BikeID as nvarchar(6),
	@SessionDate as datetime,
	@ErrorMessage as nvarchar(max) output
as
	if @BikeID is null
	begin
		set @ErrorMessage = 'Add Session: BikeID is null'
		return -1
	end

	if @RiderID is null
	begin
		set @ErrorMessage = 'Add Session: RiderID is null'
		return -1
	end

	if not exists (select * from Riders where RiderID = @RiderID)
	begin
		set @ErrorMessage = 'Add Session: ' + cast(@RiderID as nvarchar) + ' does not exist'
		return -1
	end

	if not exists (select * from Bikes where BikeID like @BikeID)
	begin
		set @ErrorMessage = 'Add Session: ' + @BikeID + ' does not exist'
		return -1
	end

	if @SessionDate is null
	begin
		set @ErrorMessage = 'Add Session: SessionDate is null'
		return -1
	end

	if ISDATE(@SessionDate) = 0 or @SessionDate < getdate()
	begin
		set @ErrorMessage = 'Add Session: ' + cast(@SessionDate as nvarchar) + ' is invalid'
		return -1
	end

	if exists (select * from Sessions where BikeID like @BikeID and SessionDate = @SessionDate)
	begin
		set @ErrorMessage = 'Add Session: ' + @BikeID + ' is already assigned'
		return -1
	end

	insert into Sessions(RiderID, BikeID, SessionDate, Laps)
	values(@RiderID, @BikeID, @SessionDate, null)
	set @ErrorMessage = 'OK'
	return 0
GO

-- Update Session Stored Procedure
if exists
(
	select *
	from sysobjects
	where name like 'UpdateSession'
)

	drop procedure UpdateSession
GO

create procedure UpdateSession
@RiderID as int,
@BikeID as nvarchar(6),
@SessionDate as datetime,
@Laps as int = null,
@ErrorMessage as nvarchar(max) output
as
	declare @OldLaps as int
	select
		@OldLaps = Laps
	from Sessions
	where SessionDate = @SessionDate and BikeID like @BikeID and RiderID = @RiderID

	if @BikeID is null
	begin
		set @ErrorMessage = 'Update Session: BikeID is null'
		return -1
	end

	if @RiderID is null
	begin
		set @ErrorMessage = 'Update Session: RiderID is null'
		return -1
	end

	if not exists (select * from Sessions where RiderID = @RiderID)
	begin
		set @ErrorMessage = 'Update Session: ' + @RiderID + ' does not exist'
		return -1
	end

	if not exists (select * from Sessions where BikeID like @BikeID)
	begin
		set @ErrorMessage = 'Update Session: ' + @BikeID + ' does not exist'
		return -1
	end

	if @SessionDate is null
	begin
		set @ErrorMessage = 'Update Session: SessionDate is null'
		return -1
	end

	if ISDATE(@SessionDate) = 0 or @SessionDate < getdate()
	begin
		set @ErrorMessage = 'Update Session: ' + @SessionDate + ' is invalid'
		return -1
	end

	if not exists (select * from Sessions where SessionDate = @SessionDate)
	begin
		set @ErrorMessage = 'Update Session: ' + @SessionDate + ' does not exist'
		return -1
	end

	if @Laps < @OldLaps
	begin
		set @ErrorMessage = 'Update Session: @Laps are less than previously held value'
		return -1
		
	end
	update aaulakh2_Lab1.dbo.Sessions
	set Laps = @Laps
	where SessionDate = @SessionDate and BikeID like @BikeID and RiderID = @RiderID
	set @ErrorMessage = 'OK'
	return 0
GO

-- Remove Class Stored Procedure
if exists
(
	select *
	from sysobjects
	where name like 'RemoveClass'
)

	drop procedure RemoveClass
GO

create procedure RemoveClass
@ClassID as nvarchar(50),
@Force as bit = 0,
@ErrorMessage as nvarchar(max) output
as
	if @ClassID is null or @ClassID like ''
	begin
		set @ErrorMessage = 'Remove Class: ClassID is null or empty'
		return -1
	end
	
	if @Force = 0 and exists (select RiderID from Riders where  ClassID like @ClassID)
	begin
		set @ErrorMessage = 'Remove Class: Rider Registered but !Force'
		return -1
	end

	if @Force = 1 and exists (select RiderID from Riders where  ClassID like @ClassID)
	begin
		delete Sessions
		where RiderID in 
		(	
			select RiderID
			from Riders
			where ClassID like (select ClassID from Class where ClassID like @CLassID)
		)

		delete Riders
		where ClassID like (select ClassID from Class where ClassID like @ClassID) 
						
	end

	delete Class
	where ClassID like @ClassID

	set @ErrorMessage = 'OK'
	return 0
GO

-- Class Info Stored Procedure
if exists
(
	select *
	from sysobjects
	where name like 'ClassInfo'
)

	drop procedure ClassInfo
GO

create procedure ClassInfo
@ClassID as nvarchar(50),
@RiderID as int = null,
@ErrorMessage as nvarchar(50) output
as
	if @ClassID is null or @ClassID like ''
	begin
		set @ErrorMessage = 'Class Info: ClassID is null or empty'
		return -1
	end

	if not exists (select ClassID from Class where ClassID like @ClassID)
	begin
		set @ErrorMessage = 'Class Info: ' + @ClassID + ' does not exist'
		return -1
	end

	if @RiderID is null
	begin
		select 
			C.ClassDescription as 'Class Description',
			R.Name
			from Class as C left outer join Riders as R
			on C.ClassID = R.ClassID
		where R.ClassID like (select 
									ClassID 
							  from Class 
							  where ClassID like @ClassID)
		set @ErrorMessage = 'Class Info: @RiderID is null'
		return 0
	end

	if @RiderID is not null
	begin
		if not exists (select RiderID from Riders where ClassID like (select 
																			ClassID 
																	  from Class 
																	  where ClassID like @ClassID))
		begin
			set @ErrorMessage = 'Class Info: ' + @RiderID + ' does not exist'
			return -1
		end

		else
		begin
			select C.ClassDescription as 'Class Description',
				   R.Name
		from Class as C left outer join Riders as R
			on C.ClassID like R.ClassID
		where
			C.ClassID like @ClassID and R.RiderID = @RiderID
		set @ErrorMessage = 'OK'
		return 0
		end
	end

GO

if exists(
	select *
	from sysobjects
	where name like 'ClassSummary'
)
	drop procedure ClassSummary
go
create procedure ClassSummary
@ClassID as nvarchar(50) = null,
@RiderID as int = null,
@ErrorMessage as nvarchar(50) output
as

	if @ClassID is null or @ClassID like ''
	begin
		set @ErrorMessage = 'Class Summary: Class ID is Null or empty'
		return -1
	end

	if not exists(select ClassID from Class where ClassID like @ClassID)
	begin
		set @ErrorMessage = 'Class Summary: '+ @ClassID + 'does not exist'
		return -1
	end

	if @RiderID is not null
	begin
		set @ErrorMessage = 'Class Summary: RiderID is null'
		return -1
	end

	if  not exists( select RiderID from Riders where RiderID = @RiderID)
	begin
		set @ErrorMessage = 'Class Summary: '+ @ClassID + 'does not exist'
		return -1
	end


	--if  not exists ( select RiderID from Riders where RiderID = @RiderID and ClassID like @RiderID)
		


go


-- Add Rider Test
-- null test
declare @pName as nvarchar(50)
declare @pClassID as nvarchar(50)
declare @errMsg as nvarchar(max)
declare @retVal as int = 0
set @pName = null
set @pClassID = 'moto_3'
set @errMsg = ''
exec @retVal = AddRider @Name= @pName, @ClassID = @pClassID, @ErrorMessage = @errMsg output
if @retVal >= 0 print 'Error Code Invalid'
select @errMsg as 'Add Rider Error Message', @retVal as 'Return Code'
go
-- Class Exists test
declare @pName as nvarchar(50)
declare @pClassID as nvarchar(50)
declare @errMsg as nvarchar(max)
declare @retVal as int = 0
set @pName = 'Mario Lopez'
set @pClassID = 'moto_73'
set @errMsg = ''
exec @retVal = AddRider @Name= @pName, @ClassID = @pClassID, @ErrorMessage = @errMsg output
if @retVal >= 0 print 'Error Code Invalid'
select @errMsg as 'Add Rider Error Message', @retVal as 'Return Code'
go

-- Add Rider Sucessful Run
declare @pName as nvarchar(50)
declare @pClassID as nvarchar(50)
declare @errMsg as nvarchar(max)
declare @retVal as int = 0
set @pName = 'Mario Lopez'
set @pClassID = 'moto_3'
set @errMsg = ''
exec @retVal = AddRider @Name= @pName, @ClassID = @pClassID, @ErrorMessage = @errMsg output
if @retVal >= 0 print 'Error Code Invalid'
select @errMsg as 'Add Rider Error Message', @retVal as 'Return Code'
select RiderID, Name from Riders where ClassID = @pClassID
GO

-- Add Session Test Code
-- RiderID Null
declare @pRiderID as int = null
declare @pBikeID as nvarchar(6) = '000H-A'
declare @pSessionDate as datetime = '2018-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

--BikeID Null
declare @pRiderID as int = 10
declare @pBikeID as nvarchar(6) = null
declare @pSessionDate as datetime = '2018-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

--RiderID !Exists
declare @pRiderID as int = 11
declare @pBikeID as nvarchar(6) = '000H-A'
declare @pSessionDate as datetime = '2018-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

--BikeID !Exists
declare @pRiderID as int = 10
declare @pBikeID as nvarchar(6) = '000H-C'
declare @pSessionDate as datetime = '2018-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

--Date Null
declare @pRiderID as int = 10
declare @pBikeID as nvarchar(6) = '000H-A'
declare @pSessionDate as datetime = null
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

-- Date Invalid
declare @pRiderID as int = null
declare @pBikeID as nvarchar(6) = '000H-A'
declare @pSessionDate as datetime = '2017-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

-- Succesful Add Session Run
declare @pRiderID as int = 10
declare @pBikeID as nvarchar(6) = '000H-A'
declare @pSessionDate as datetime = '2018-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

-- BikeID already assigned
declare @pRiderID as int = 10
declare @pBikeID as nvarchar(6) = '000H-A'
declare @pSessionDate as datetime = '2018-09-01'
declare @Error as nvarchar(max)
declare @retVal as int = 0
exec @retVal = AddSession @RiderID = @pRiderID, @BikeID = @pBikeID, @SessionDate = @pSessionDate, @ErrorMessage = @Error output
select @Error as 'Add Session Error Message', @retVal as 'Return Code'
GO

-- Remove Rider Test Code
-- RiderID Null
declare @retVal as int = 0
declare @pRiderID as int = null
declare @pForce as bit = 0
declare @Error as nvarchar(max) = ''
exec @retVal = RemoveRider @RiderID = pRiderID, @Force = @pForce, @ErrorMessage = @Error output
select @Error as 'Remove Rider Error Message', @retVal as 'Return Code'
GO

----RiderID !Exist
--declare @retVal as int = 0
--declare @pRiderID as int = 11
--declare @pForce as bit = 1
--declare @Error as nvarchar(max) = ''
--exec @retVal = RemoveRider @RiderID = pRiderID, @Force = @pForce, @ErrorMessage = @Error output
--select @Error as 'Remove Rider Error Message', @retVal as 'Return Code'
--GO

---- !Force & SessionData
--declare @retVal as int = 0
--declare @pRiderID as int = 10
--declare @pForce as bit = 0
--declare @Error as nvarchar(max) = ''
--exec @retVal = RemoveRider @RiderID = pRiderID, @Force = @pForce, @ErrorMessage = @Error output
--select @Error as 'Remove Rider Error Message', @retVal as 'Return Code'
--GO

---- Force & SessionData
--declare @retVal as int = 0
--declare @pRiderID as int = 10
--declare @pForce as bit = 1
--declare @Error as nvarchar(max) = ''
--exec @retVal = RemoveRider @RiderID = pRiderID, @Force = @pForce, @ErrorMessage = @Error output
--select @Error as 'Remove Rider Error Message', @retVal as 'Return Code'
--GO

---- Remove Rider Sucessful Run
--declare @retVal as int = 0
--declare @pRiderID as int = 10
--declare @pForce as bit = 1
--declare @Error as nvarchar(max) = ''
--exec @retVal = RemoveRider @RiderID = pRiderID, @Force = @pForce, @ErrorMessage = @Error output
--select @Error as 'Remove Rider Error Message', @retVal as 'Return Code'
--GO



