CREATE OR ALTER PROCEDURE dbo.InsertarError
	@inSUSER_SNAME				VARCHAR(32)
	, @inERROR_NUMBER			INT
	, @inERROR_STATE			INT
	, @inERROR_SEVERITY			INT
	, @inERROR_LINE				INT
	, @inERROR_PROCEDURE		VARCHAR(32)
	, @inERROR_MESSAGE			VARCHAR(512)
	, @inGETDATE				DATETIME

AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.DBError (
			[UserName]
			, [Number]
			, [State]
			, [Severity]
			, [Line]
			, [Procedure]
			, [Message]
			, [DateTime]
		) VALUES (
			@inSUSER_SNAME
			, @inERROR_NUMBER
			, @inERROR_STATE
			, @inERROR_SEVERITY
			, @inERROR_LINE
			, @inERROR_PROCEDURE
			, @inERROR_MESSAGE
			, @inGETDATE
		);

	SET NOCOUNT OFF;
END