CREATE OR ALTER PROCEDURE dbo.FacturaObtenerPendienteMasAntigua
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
	SET @descripcionEvento = 'Exito: Se obtuvo la factura pendiente de '
							+ CAST(@inIDPropiedad AS VARCHAR) 
							+ ' mas antigua';

	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.Propiedad WHERE ID = @inIDPropiedad)
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: Propiedad '
									+ CAST(@inIDPropiedad AS VARCHAR)
									+ 'no encontrada al intentar obtener factura pendiente mas antigua';
		END;

		IF @outResultCode = 0
		BEGIN
			SELECT TOP 1 
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
										+ CAST(@inIDPropiedad AS VARCHAR) 
										+ ' al intentar obtener la mas antigua';
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
	END CATCH;
	SET NOCOUNT OFF;
END;