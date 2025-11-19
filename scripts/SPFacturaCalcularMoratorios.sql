CREATE OR ALTER PROCEDURE dbo.FacturaCalcularMoratorios
	@inIDFactura 			INT
	, @inUserName 			VARCHAR(32)
	, @inIP 				VARCHAR(32)
	, @outMontoMoratorios 	MONEY OUTPUT
	, @outResultCode 		INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @descripcionEvento 	VARCHAR(256);
	DECLARE @resultBitacora 	INT;
	DECLARE @diasMora 			INT;
	DECLARE @tipoEvento 		INT = 3; -- flag para determinar si hay error o no, "Calcular moratorios" por default
	DECLARE @tasaDiaria 		DECIMAL(10,6);
	DECLARE @totalFactura 		MONEY;
	DECLARE @fechaLimite 		DATE;
	DECLARE @fechaOperacion 	DATE;
	
	SET @outResultCode = 0;
	SET @outMontoMoratorios = 0;
	SET @descripcionEvento = 'Se calcularon los intereses moratorios de la factura ' + CAST(@inIDFactura AS VARCHAR);
	SET @fechaOperacion = GETDATE();

	BEGIN TRY
		BEGIN TRANSACTION;

		IF NOT EXISTS (SELECT 1 FROM dbo.Factura WHERE ID = @inIDFactura)
		BEGIN
			SET @outResultCode = 50001; -- no encontrado
			SET @descripcionEvento = 'Error: Factura '
									+ CAST(@inIDFactura AS VARCHAR) 
									+ ' no encontrada al intentar calcular moratorios';
		END;

		IF @outResultCode = 0
		BEGIN
			SELECT 
				@fechaLimite = F.FechaLimitePago
				, @totalFactura = F.TotalPagarOriginal
			FROM dbo.Factura F
			WHERE F.ID = @inIDFactura;

			IF @fechaOperacion <= @fechaLimite
			BEGIN
				SET @outResultCode = 50004; -- estado no valido
				SET @descripcionEvento = 'Error: La factura '
										+ CAST(@inIDFactura AS VARCHAR) 
										+ ' no esta vencida, no aplican moratorios';
			END;
		END;

		IF @outResultCode = 0
		BEGIN
			SET @diasMora = DATEDIFF(DAY, @fechaLimite, @fechaOperacion);
			SET @tasaDiaria = 0.04 / 30.0;
			SET @outMontoMoratorios = @totalFactura * @tasaDiaria * @diasMora;

			IF @outMontoMoratorios <= 0
			BEGIN
				SET @outResultCode = 50002; -- validacion fallida
				SET @descripcionEvento = 'Error: El calculo de moratorios de la factura '
										+ CAST(@inIDFactura AS VARCHAR) 
										+ ' resulto en monto invalido';
			END;
		END;

		IF @outResultCode = 0
		BEGIN
			INSERT INTO dbo.Linea (
				[Monto]
				, [IDFactura]
				, [IDCC]
			) VALUES (
				@outMontoMoratorios
				, @inIDFactura
				, 6 -- moratorios
			);

			UPDATE dbo.Factura 
			SET TotalPagarFinal = TotalPagarFinal + @outMontoMoratorios
			WHERE ID = @inIDFactura;
		END;

		IF (@outResultCode != 0)
		BEGIN
			SET @tipoEvento = 11;
			ROLLBACK TRANSACTION;
		END
		ELSE
		BEGIN
			COMMIT TRANSACTION;
		END;

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