CREATE OR ALTER PROCEDURE dbo.ValidarCredenciales
	@inUserName 		VARCHAR(32)
	, @inPassword 		VARCHAR(256)
	, @inIP 			VARCHAR(32)
	, @outEsAdmin 		BIT OUTPUT
	, @outResultCode 	INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @descripcionEvento 	VARCHAR(256);
	DECLARE @resultBitacora 	INT;
	DECLARE @tipoEvento 		INT = 12;
	DECLARE @tipoUsuario		INT;
	
	SET @outResultCode 		= 0;
	SET @outEsAdmin 		= 0;
	SET @descripcionEvento 	= 'Exito: Login exitoso para usuario ' + @inUserName;
	SET @tipoUsuario 		= 2;

	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UserName = @inUserName AND EsActivo = 1)
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: Usuario no encontrado o inactivo - ' + @inUserName;
		END;

		IF @outResultCode = 0 AND NOT EXISTS (
			SELECT 1 FROM dbo.Usuario U 
			WHERE U.[UserName] = @inUserName 
			AND U.[Password] = @inPassword
			AND U.EsActivo = 1
		)
		BEGIN
			SET @outResultCode = 50002; -- validacion fallida
			SET @descripcionEvento = 'Error: Credenciales invalidas para usuario ' + @inUserName;
		END;

		-- asignar tipo de usuario si las credenciales son validas
		IF @outResultCode = 0
		BEGIN
			SELECT @tipoUsuario = U.IDTipo
			FROM dbo.Usuario U
			WHERE UserName = @inUserName AND EsActivo = 1;
			
			IF (@tipoUsuario = 1)
			BEGIN
				SET @outEsAdmin = 1;
			END;
		END;

		IF (@outResultCode != 0)
		BEGIN
			SET @tipoEvento = 11; -- error sistema
		END

		EXEC dbo.InsertarBitacora 
			@inIP,
			@inUserName,
			@descripcionEvento,
			@tipoEvento;

	END TRY
	BEGIN CATCH
		SET @outResultCode = 50008; -- error bd
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
	END CATCH;
	SET NOCOUNT OFF;
END;