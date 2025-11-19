CREATE OR ALTER PROCEDURE dbo.ListarFacturasPendientes
	@inIDPropiedad 		INT
	, @inUserName 		VARCHAR(32)
	, @inIP 			VARCHAR(32)
	, @outResultCode 	INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @descripcionEvento 	VARCHAR(256);
	DECLARE @resultBitacora 	INT;
	DECLARE @tipoEvento 		INT = 2; -- flag para determinar si hay error o no, "Calcular moratorios" por default
	 
	SET @outResultCode = 0;
	SET @descripcionEvento = 'Exito: Se listaron las facturas pendientes de '
							+ CAST(@inIDPropiedad AS VARCHAR);

	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.Propiedad WHERE ID = @inIDPropiedad)
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: Propiedad '
									+ CAST(@inIDPropiedad AS VARCHAR)
									+ ' no encontrada al intentar listar facturas pendientes';
		END;

		IF @outResultCode = 0
		BEGIN
			SELECT 
				F.ID
				, F.FechaFactura
				, F.FechaLimitePago
				, F.FechaCorteAgua
				, F.IDPropiedad
				, F.TotalPagarOriginal
				, F.EstadoFactura
				, F.IDTipoMedioPago
				, F.TotalPagarFinal
			FROM dbo.Factura F
			WHERE F.IDPropiedad = @inIDPropiedad
				AND F.EstadoFactura = 0
			ORDER BY F.FechaLimitePago ASC;

			IF @@ROWCOUNT = 0
			BEGIN
				SET @outResultCode = 50009; -- no facturas pendientes
				SET @descripcionEvento = 'No hay facturas pendientes para la propiedad ' 
										+ CAST(@inIDPropiedad AS VARCHAR);
			END;
		END;
		
		IF (@outResultCode != 0)
		BEGIN
			SET @tipoEvento = 11; -- error
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