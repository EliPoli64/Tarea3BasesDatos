CREATE OR ALTER PROCEDURE dbo.InsertarBitacora
	@inIP 				VARCHAR(32)
	, @inUsuario 		VARCHAR(32)
	, @inDescripcion 	VARCHAR(256)
	, @inTipoEvento 	INT
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY

		DECLARE @userID INT;
		SELECT @userID = U.ID
			FROM dbo.Usuario U
			WHERE U.UserName = @inUsuario;

		INSERT INTO dbo.Bitacora (	
			PostInIP
			, [IDPostByUser]
			, Descripcion
			, IDTipoEvento
			, [PostTime]
		) VALUES (
			@inIP
			, @userID
			, @inDescripcion
			, @inTipoEvento
			, GETDATE()
		);

	END TRY
	BEGIN CATCH

		DECLARE @ErrorNumber INT = ERROR_NUMBER();
		DECLARE @ErrorState INT = ERROR_STATE();
		DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
		DECLARE @ErrorLine INT = ERROR_LINE();
		DECLARE @ErrorProcedure VARCHAR(32) = ERROR_PROCEDURE();
		DECLARE @ErrorMessage VARCHAR(512) = ERROR_MESSAGE();
		DECLARE @UserName VARCHAR(32) = SUSER_SNAME();
		DECLARE @CurrentDate DATETIME = GETDATE();

		EXEC dbo.InsertarError
			@inSUSER_SNAME      = @UserName,
			@inERROR_NUMBER     = @ErrorNumber,
			@inERROR_STATE      = @ErrorState,
			@inERROR_SEVERITY   = @ErrorSeverity,
			@inERROR_LINE       = @ErrorLine,
			@inERROR_PROCEDURE  = @ErrorProcedure,
			@inERROR_MESSAGE    = @ErrorMessage,
			@inGETDATE          = @CurrentDate;
	
	END CATCH
	SET NOCOUNT OFF;
END;