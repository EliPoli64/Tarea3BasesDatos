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

		-- Tabla temporal para procesar las lecturas
		DECLARE @Lecturas TABLE (
			NumMedidor  VARCHAR(32),
			TipoMov     INT,
			Valor       FLOAT,
			IDPropiedad INT,
			UltimaLecturaMedidor FLOAT,
			SaldoM3 FLOAT
		) ;

		-- Insertar datos con información actual de la propiedad
		INSERT INTO @Lecturas
		(
			NumMedidor,
			TipoMov,
			Valor,
			IDPropiedad,
			UltimaLecturaMedidor,
			SaldoM3
		)
		SELECT
			L.value('@numeroMedidor' , 'VARCHAR(32)') AS NumMedidor,
			L.value('@tipoMovimientoId','INT') AS TipoMov,
			L.value('@valor' , 'FLOAT') AS Valor,
			P.ID AS IDPropiedad,
			P.UltimaLecturaMedidor,
			P.SaldoM3
		FROM @Xml.nodes('/LecturasMedidor/Lectura') AS T(L)
		INNER JOIN dbo.Propiedad AS P
			ON P.NumMedidor = L.value('@numeroMedidor', 'VARCHAR(32)') ;

		-- Verificar si existen medidores no encontrados
		IF EXISTS (
			SELECT 1
			FROM @Xml.nodes('/LecturasMedidor/Lectura') AS T(L)
			WHERE NOT EXISTS (
				SELECT 1 
				FROM dbo.Propiedad P 
				WHERE P.NumMedidor = L.value('@numeroMedidor', 'VARCHAR(32)')
			)
		)
		BEGIN
			SET @outResultCode = 50001 ;
			SET @descripcionEvento = 'Error: Al menos un medidor de LecturasMedidor no existe en Propiedad' ;
			GOTO FinLect;
		END ;

		BEGIN TRAN ;

		-- Procesar TipoMov = 1 (Lecturas de consumo)
		UPDATE P
		SET 
			UltimaLecturaMedidor = L.Valor,
			SaldoM3 = P.SaldoM3 + 
				CASE 
					WHEN P.UltimaLecturaMedidor IS NULL THEN 0
					WHEN L.Valor - P.UltimaLecturaMedidor < 0 THEN 0
					ELSE L.Valor - P.UltimaLecturaMedidor
				END
		FROM dbo.Propiedad P
		INNER JOIN @Lecturas L ON P.ID = L.IDPropiedad
		WHERE L.TipoMov = 1;

		-- Insertar movimientos para TipoMov = 1
		INSERT INTO dbo.MovConsumo(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		SELECT
			@FechaOperacion,
			CASE 
				WHEN L.UltimaLecturaMedidor IS NULL THEN 0
				WHEN L.Valor - L.UltimaLecturaMedidor < 0 THEN 0
				ELSE L.Valor - L.UltimaLecturaMedidor
			END AS Monto,
			P.SaldoM3 AS NuevoSaldo,
			1 AS IDTipo,
			L.IDPropiedad
		FROM @Lecturas L
		INNER JOIN dbo.Propiedad P ON L.IDPropiedad = P.ID
		WHERE L.TipoMov = 1;

		-- Procesar TipoMov = 2 (Pagos/Abonos)
		UPDATE P
		SET SaldoM3 = P.SaldoM3 - 
			CASE 
				WHEN L.Valor > P.SaldoM3 THEN P.SaldoM3
				ELSE L.Valor
			END
		FROM dbo.Propiedad P
		INNER JOIN @Lecturas L ON P.ID = L.IDPropiedad
		WHERE L.TipoMov = 2;

		-- Insertar movimientos para TipoMov = 2
		INSERT INTO dbo.MovConsumo(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		SELECT
			@FechaOperacion,
			-CASE 
				WHEN L.Valor > L.SaldoM3 THEN L.SaldoM3
				ELSE L.Valor
			END AS Monto,
			P.SaldoM3 AS NuevoSaldo,
			2 AS IDTipo,
			L.IDPropiedad
		FROM @Lecturas L
		INNER JOIN dbo.Propiedad P ON L.IDPropiedad = P.ID
		WHERE L.TipoMov = 2;

		-- Procesar TipoMov = 3 (Recargas/Incrementos)
		UPDATE P
		SET SaldoM3 = P.SaldoM3 + L.Valor
		FROM dbo.Propiedad P
		INNER JOIN @Lecturas L ON P.ID = L.IDPropiedad
		WHERE L.TipoMov = 3;

		-- Insertar movimientos para TipoMov = 3
		INSERT INTO dbo.MovConsumo(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		SELECT
			@FechaOperacion,
			L.Valor AS Monto,
			P.SaldoM3 AS NuevoSaldo,
			3 AS IDTipo,
			L.IDPropiedad
		FROM @Lecturas L
		INNER JOIN dbo.Propiedad P ON L.IDPropiedad = P.ID
		WHERE L.TipoMov = 3;

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