CREATE OR ALTER PROCEDURE dbo.validarCredenciales
	
	@inIP						VARCHAR(32)
	, @inUserName				VARCHAR(32)
	, @incontraseña				VARCHAR(32)
	, @outResultCode 			INT OUTPUT
	, @outIDUsuario	 			INT OUTPUT
	, @outEsAdmin	 			INT OUTPUT

AS
BEGIN
	BEGIN TRY
		DECLARE @descripcionEvento	VARCHAR(256);
		DECLARE @resultBitacora		INT;

		SET @descripcionEvento	= 'Inicio de sesion exitoso';
		SET @outResultCode = 0;
		SET @outIDUsuario = -1;

		SET NOCOUNT ON;

		IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UserName = @inUserName AND EsActivo = 1 AND [Password] = @incontraseña )
		BEGIN
			SET @outResultCode = 50006; -- Usuario no encontrado o contraseña invalida
			SET @descripcionEvento = 'Error: Validacion '
									+ CAST(@inUserName AS VARCHAR) 
									+ ' el usuario no existe, esta inactivo o la contraseña es invalida.';
		END;

		IF @outResultCode = 0
		BEGIN
			EXEC dbo.InsertarBitacora 
			@inIP
			, @inUserName
			, @descripcionEvento
			, 12 -- Login de usuario
			, @outResultCode = @resultBitacora OUTPUT;

			SELECT 
                @outIDUsuario = ID, 
                -- Transformar IDTipo a Booleano (1 o 0)
                @outEsAdmin = CASE WHEN IDTipo = 1 THEN 1 ELSE 0 END 
            FROM dbo.Usuario 
            WHERE UserName = @inUserName;
		END;

		

	END TRY
	BEGIN CATCH
		SET @outResultCode = 50008; -- error bd
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