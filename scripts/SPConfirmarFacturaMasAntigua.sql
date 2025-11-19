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