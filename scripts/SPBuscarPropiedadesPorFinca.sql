CREATE OR ALTER PROCEDURE dbo.BuscarPropiedadesPorFinca
	@inNumFinca         VARCHAR(16)
	, @inUserName       VARCHAR(32)
	, @inIP             VARCHAR(32)
	, @outResultCode    INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @descripcionEvento  VARCHAR(256);
	DECLARE @resultBitacora     INT;
	DECLARE @tipoEvento         INT = 1;
	
	SET @outResultCode = 0;
	SET @descripcionEvento = 'Exito: Busqueda de propiedad por finca ' + @inNumFinca;

	BEGIN TRY
		SELECT 
			P.ID
			, P.NumFinca
			, P.Area
			, P.ValorPropiedad
			, P.FechaRegistro
			, TU.Nombre AS TipoUso
			, TA.Nombre AS TipoArea
		FROM dbo.Propiedad P
		INNER JOIN dbo.TipoUsoPropiedad TU ON P.IDTipoUso = TU.ID
		INNER JOIN dbo.TipoAreaPropiedad TA ON P.IDTipoArea = TA.ID
		WHERE P.NumFinca = @inNumFinca;

		IF @@ROWCOUNT = 0
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: No se encontro propiedad con finca ' + @inNumFinca;
		END;

		IF (@outResultCode != 0)
		BEGIN
			SET @tipoEvento = 11;
		END

		EXEC dbo.InsertarBitacora 
			@inIP
			, @inUserName
			, @descripcionEvento
			, @tipoEvento;

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