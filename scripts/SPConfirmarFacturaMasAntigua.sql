CREATE OR ALTER PROCEDURE dbo.ConfirmarFacturaMasAntigua
	@inIDFactura            INT
	, @inTipoMedioPago      INT
	, @inUserName           VARCHAR(32)
	, @inIP                 VARCHAR(32)
	, @outCodigoComprobante VARCHAR(32) OUTPUT
	, @outResultCode        INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @descripcionEvento  VARCHAR(256);
	DECLARE @resultBitacora     INT;
	DECLARE @tipoEvento         INT = 4; -- pago factura
	DECLARE @montoMoratorios    MONEY = 0;
	DECLARE @idPropiedad        INT;
	
	SET @outResultCode = 0;
	SET @outCodigoComprobante = 'CPB-' + CAST(NEWID() AS VARCHAR(36));

	BEGIN TRY
		BEGIN TRANSACTION;

		SELECT @idPropiedad = IDPropiedad 
		FROM dbo.Factura 
		WHERE ID = @inIDFactura;

		IF @idPropiedad IS NULL
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: Factura no encontrada para confirmar pago - ' + CAST(@inIDFactura AS VARCHAR);
		END;

		IF @outResultCode = 0 AND GETDATE() > (SELECT FechaLimitePago FROM dbo.Factura WHERE ID = @inIDFactura)
		BEGIN
			EXEC dbo.FacturaCalcularMoratorios 
				@inIDFactura
				, @inUserName
				, @inIP
				, @outMontoMoratorios = @montoMoratorios OUTPUT
				, @outResultCode = @outResultCode OUTPUT;
		END;

		IF @outResultCode = 0
		BEGIN
			UPDATE dbo.Factura 
			SET EstadoFactura = 1
				, IDTipoMedioPago = @inTipoMedioPago
			WHERE ID = @inIDFactura;

			INSERT INTO dbo.ComprobantePago (
				[Fecha]
				, [Codigo]
				, [IDPropiedad]
			) VALUES (
				GETDATE()
				, @outCodigoComprobante
				, @idPropiedad
			);

			SET @descripcionEvento = 'Exito: Pago confirmado para factura ' + CAST(@inIDFactura AS VARCHAR) + ' - Comprobante: ' + @outCodigoComprobante;
		END;

		IF @outResultCode = 0
		BEGIN
			COMMIT TRANSACTION;
		END
		ELSE
		BEGIN
			ROLLBACK TRANSACTION;
			SET @tipoEvento = 11;
		END

		EXEC dbo.InsertarBitacora 
			@inIP
			, @inUserName
			, @descripcionEvento
			, @tipoEvento;

	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRANSACTION;
		END;

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