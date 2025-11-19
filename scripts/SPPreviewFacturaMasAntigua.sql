CREATE OR ALTER PROCEDURE dbo.PreviewFacturaMasAntigua
	@inIDPropiedad 			INT
	, @inUserName 			VARCHAR(32)
	, @inIP 				VARCHAR(32)
	, @outIDFactura 		INT OUTPUT
	, @outMontoMoratorios 	MONEY OUTPUT
	, @outTotalPagar 		MONEY OUTPUT
	, @outResultCode 		INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @descripcionEvento VARCHAR(256);
	DECLARE @resultBitacora INT;
	DECLARE @tipoEvento INT = 2;
	DECLARE @fechaLimite DATE;
	DECLARE @totalOriginal MONEY;
	DECLARE @diasMora INT;
	DECLARE @tasaDiaria DECIMAL(10,6);
	
	SET @outResultCode = 0;
	SET @outIDFactura = 0;
	SET @outMontoMoratorios = 0;
	SET @outTotalPagar = 0;
	SET @descripcionEvento = 'Exito: Preview de factura mas antigua para propiedad ' + CAST(@inIDPropiedad AS VARCHAR);

	BEGIN TRY
		SELECT TOP 1 
			@outIDFactura = F.ID
			, @fechaLimite = F.FechaLimitePago
			, @totalOriginal = F.TotalPagarOriginal
			, @outTotalPagar = F.TotalPagarFinal
		FROM dbo.Factura F
		WHERE F.IDPropiedad = @inIDPropiedad
			AND F.EstadoFactura = 0
		ORDER BY F.FechaLimitePago ASC;

		IF @outIDFactura = 0
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: No hay facturas pendientes para preview en propiedad '
                                     + CAST(@inIDPropiedad AS VARCHAR);
		END;

		IF @outResultCode = 0 AND GETDATE() > @fechaLimite
		BEGIN
			SET @diasMora = DATEDIFF(DAY, @fechaLimite, GETDATE());
			SET @tasaDiaria = 0.04 / 30.0;
			SET @outMontoMoratorios = @totalOriginal * @tasaDiaria * @diasMora;
			SET @outTotalPagar = @outTotalPagar + @outMontoMoratorios;
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