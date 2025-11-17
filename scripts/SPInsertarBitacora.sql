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
			SUSER_SNAME()
			, ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
			, GETDATE()
		);
	
	END CATCH
	SET NOCOUNT OFF;
END;