CREATE OR ALTER PROCEDURE dbo.XMLProcesarLecturasMedidor
	@Xml            XML,
	@FechaOperacion DATE,
	@inUserName     VARCHAR(32),
	@inIP           VARCHAR(32),
	@outResultCode  INT OUTPUT
AS
BEGIN 
	SET NOCOUNT ON ;

	DECLARE @descripcionEvento VARCHAR(256);
	DECLARE @resultBitacora INT;
	DECLARE @tipoEvento INT = 2;

	SET @outResultCode = 0;
	SET @descripcionEvento = 'Éxito: Lecturas de medidor procesadas correctamente' ;

	BEGIN TRY
		IF @Xml IS NULL
		   OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
		BEGIN
			SET @outResultCode = 50002;
			SET @descripcionEvento = 'Error: XML de LecturasMedidor vacío' ;
			GOTO FinLect ;
		END ;

		IF @FechaOperacion IS NULL
		BEGIN
			SET @outResultCode = 50002;
			SET @descripcionEvento = 'Error: Fecha de operación no proporcionada para LecturasMedidor' ;
			GOTO FinLect ;
		END ;

		IF @Xml.exist('/LecturasMedidor/Lectura') = 0
		BEGIN
			SET @outResultCode = 50012;
			SET @descripcionEvento = 'Sin cambios: No hay nodos <Lectura> en LecturasMedidor' ;
			GOTO FinLect ;
		END ;

		DECLARE @Lecturas TABLE (
			NumMedidor  VARCHAR(32),
			TipoMov     INT,
			Valor       FLOAT,
			IDPropiedad INT
		) ;

		INSERT INTO @Lecturas
		(
			NumMedidor,
			TipoMov,
			Valor,
			IDPropiedad
		)
		SELECT
			L.value('@numeroMedidor' , 'VARCHAR(32)') AS NumMedidor,
			L.value('@tipoMovimientoId','INT') AS TipoMov,
			L.value('@valor' , 'FLOAT') AS Valor,
			P.ID                                       AS IDPropiedad
		FROM @Xml.nodes('/LecturasMedidor/Lectura') AS T(L)
		LEFT JOIN dbo.Propiedad AS P
			ON P.NumMedidor = L.value('@numeroMedidor', 'VARCHAR(32)') ;

		IF EXISTS (
			SELECT 1
			FROM @Lecturas
			WHERE IDPropiedad IS NULL
		)
		BEGIN
			SET @outResultCode = 50001 ;
			SET @descripcionEvento = 'Error: Al menos un medidor de LecturasMedidor no existe en Propiedad' ;
			GOTO FinLect;
		END ;

		BEGIN TRAN ;

		DECLARE @NumMedidor VARCHAR(32);
		DECLARE @TipoMov INT;
		DECLARE @Valor FLOAT;
		DECLARE @IDPropiedad INT;

		DECLARE lecturas_cursor CURSOR FOR
		SELECT NumMedidor, TipoMov, Valor, IDPropiedad
		FROM @Lecturas;

		OPEN lecturas_cursor;
		FETCH NEXT FROM lecturas_cursor INTO @NumMedidor, @TipoMov, @Valor, @IDPropiedad;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @TipoMov = 1
			BEGIN
				DECLARE @ConsumoDiff FLOAT;
				DECLARE @UltimaLectura FLOAT;

				SELECT @UltimaLectura = UltimaLecturaMedidor
				FROM dbo.Propiedad
				WHERE ID = @IDPropiedad;

				SET @ConsumoDiff = CASE
					WHEN @UltimaLectura IS NULL THEN 0
					WHEN @Valor - @UltimaLectura < 0 THEN 0
					ELSE @Valor - @UltimaLectura
				END;

				UPDATE dbo.Propiedad
				SET UltimaLecturaMedidor = @Valor,
					SaldoM3 = SaldoM3 + @ConsumoDiff
				WHERE ID = @IDPropiedad;

				INSERT INTO dbo.MovConsumo(
					Fecha,
					Monto,
					NuevoSaldo,
					IDTipo,
					IDPropiedad
				)
				VALUES(
					@FechaOperacion,
					@ConsumoDiff,
					(SELECT SaldoM3 FROM dbo.Propiedad WHERE ID = @IDPropiedad),
					1,
					@IDPropiedad
				);
			END
			ELSE IF @TipoMov = 2
			BEGIN
				DECLARE @ValorAplicado FLOAT;
				DECLARE @SaldoActual FLOAT;

				SELECT @SaldoActual = SaldoM3
				FROM dbo.Propiedad
				WHERE ID = @IDPropiedad;

				SET @ValorAplicado = CASE
					WHEN @Valor > @SaldoActual THEN @SaldoActual
					ELSE @Valor
				END;

				UPDATE dbo.Propiedad
				SET SaldoM3 = SaldoM3 - @ValorAplicado
				WHERE ID = @IDPropiedad;

				INSERT INTO dbo.MovConsumo(
					Fecha,
					Monto,
					NuevoSaldo,
					IDTipo,
					IDPropiedad
				)
				VALUES(
					@FechaOperacion,
					-@ValorAplicado,
					(SELECT SaldoM3 FROM dbo.Propiedad WHERE ID = @IDPropiedad),
					2,
					@IDPropiedad
				);
			END
			ELSE IF @TipoMov = 3
			BEGIN
				UPDATE dbo.Propiedad
				SET SaldoM3 = SaldoM3 + @Valor
				WHERE ID = @IDPropiedad;

				INSERT INTO dbo.MovConsumo(
					Fecha,
					Monto,
					NuevoSaldo,
					IDTipo,
					IDPropiedad
				)
				VALUES(
					@FechaOperacion,
					@Valor,
					(SELECT SaldoM3 FROM dbo.Propiedad WHERE ID = @IDPropiedad),
					3,
					@IDPropiedad
				);
			END

			FETCH NEXT FROM lecturas_cursor INTO @NumMedidor, @TipoMov, @Valor, @IDPropiedad;
		END;

		CLOSE lecturas_cursor;
		DEALLOCATE lecturas_cursor;

		COMMIT TRAN;

FinLect:
		IF @outResultCode <> 0
		BEGIN
			SET @tipoEvento = 11 ;
		END;

		EXEC dbo.InsertarBitacora
			@inIP,
			@inUserName,
			@descripcionEvento,
			@tipoEvento;
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
		BEGIN
			ROLLBACK TRAN ;
		END;

		SET @outResultCode = 50008 ;

		INSERT INTO dbo.DBError
		(
			[UserName],
			[Number],
			[State],
			[Severity],
			[Line],
			[Procedure],
			[Message],
			[DateTime]
		)
		VALUES
		(
			SUSER_SNAME(),
			ERROR_NUMBER(),
			ERROR_STATE(),
			ERROR_SEVERITY(),
			ERROR_LINE(),
			ERROR_PROCEDURE(),
			ERROR_MESSAGE(),
			GETDATE()
		);
	END CATCH;

	SET NOCOUNT OFF;
END;