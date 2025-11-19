CREATE OR ALTER PROCEDURE dbo.XMLProcesarLecturasMedidor
	@Xml 				XML
	, @FechaOperacion 	DATE
	, @inUserName 		VARCHAR(32)
	, @inIP 			VARCHAR(32)
	, @outResultCode 	INT OUTPUT
AS
BEGIN 
	SET NOCOUNT ON;

	DECLARE @descripcionEvento VARCHAR(256);
	DECLARE @tipoEvento INT = 2;

	SET @outResultCode = 0;
	SET @descripcionEvento = 'Éxito: Lecturas de medidor procesadas correctamente';

	BEGIN TRY
		IF @Xml IS NULL
		   OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
		BEGIN
			SET @outResultCode = 50002;
			SET @descripcionEvento = 'Error: XML de LecturasMedidor vacío';
			GOTO FinLect;
		END;

		IF @FechaOperacion IS NULL
		BEGIN
			SET @outResultCode = 50002;
			SET @descripcionEvento = 'Error: Fecha de operación no proporcionada para LecturasMedidor';
			GOTO FinLect;
		END;

		IF @Xml.exist('/LecturasMedidor/Lectura') = 0
		BEGIN
			SET @outResultCode = 50012;
			SET @descripcionEvento = 'Sin cambios: No hay nodos <Lectura> en LecturasMedidor';
			GOTO FinLect;
		END;

		BEGIN TRAN;

		WITH Lecturas AS (
			SELECT
				L.value('@numeroMedidor' , 'VARCHAR(32)') AS NumMedidor
				, L.value('@tipoMovimientoId','INT') AS TipoMov
				, L.value('@valor' , 'FLOAT') AS Valor
				, P.ID AS IDPropiedad
			FROM @Xml.nodes('/LecturasMedidor/Lectura') AS T(L)
			INNER JOIN dbo.Propiedad AS P
				ON P.NumMedidor = L.value('@numeroMedidor', 'VARCHAR(32)')
		)
		, Consumos AS (
			SELECT
				L.IDPropiedad
				, L.Valor
				, CASE 
					WHEN P.UltimaLecturaMedidor IS NULL THEN 0
					WHEN L.Valor - P.UltimaLecturaMedidor < 0 THEN 0
					ELSE L.Valor - P.UltimaLecturaMedidor
				END AS ConsumoDiff
			FROM Lecturas L
			INNER JOIN dbo.Propiedad P ON P.ID = L.IDPropiedad
			WHERE L.TipoMov = 1
		)
		, Abonos AS (
			SELECT
				L.IDPropiedad
				, L.Valor
				, CASE 
					WHEN L.Valor > P.SaldoM3 THEN P.SaldoM3
					ELSE L.Valor
				END AS ValorAplicado
			FROM Lecturas L
			INNER JOIN dbo.Propiedad P ON P.ID = L.IDPropiedad
			WHERE L.TipoMov = 2
		)
		UPDATE P
		SET UltimaLecturaMedidor = C.Valor
			, SaldoM3 = P.SaldoM3 + C.ConsumoDiff
		FROM dbo.Propiedad P
		INNER JOIN Consumos C ON C.IDPropiedad = P.ID;

		UPDATE P
		SET SaldoM3 = P.SaldoM3 - A.ValorAplicado
		FROM dbo.Propiedad P
		INNER JOIN Abonos A ON A.IDPropiedad = P.ID;

		UPDATE P
		SET SaldoM3 = P.SaldoM3 + L.Valor
		FROM dbo.Propiedad P
		INNER JOIN (
			SELECT
				L.value('@numeroMedidor' , 'VARCHAR(32)') AS NumMedidor
				, L.value('@valor' , 'FLOAT') AS Valor
				, P.ID AS IDPropiedad
			FROM @Xml.nodes('/LecturasMedidor/Lectura') AS T(L)
			INNER JOIN dbo.Propiedad AS P
				ON P.NumMedidor = L.value('@numeroMedidor', 'VARCHAR(32)')
			WHERE L.value('@tipoMovimientoId','INT') = 3
		) L ON L.IDPropiedad = P.ID;

		INSERT INTO dbo.MovConsumo(
			Fecha
			, Monto
			, NuevoSaldo
			, IDTipo
			, IDPropiedad
		)
		SELECT
			@FechaOperacion
			, C.ConsumoDiff
			, P.SaldoM3
			, 1
			, C.IDPropiedad
		FROM Consumos C
		INNER JOIN dbo.Propiedad P ON P.ID = C.IDPropiedad;

		INSERT INTO dbo.MovConsumo(
			Fecha
			, Monto
			, NuevoSaldo
			, IDTipo
			, IDPropiedad
		)
		SELECT
			@FechaOperacion
			, -A.ValorAplicado
			, P.SaldoM3
			, 2
			, A.IDPropiedad
		FROM Abonos A
		INNER JOIN dbo.Propiedad P ON P.ID = A.IDPropiedad;

		INSERT INTO dbo.MovConsumo(
			Fecha
			, Monto
			, NuevoSaldo
			, IDTipo
			, IDPropiedad
		)
		SELECT
			@FechaOperacion
			, L.Valor
			, P.SaldoM3
			, 3
			, L.IDPropiedad
		FROM (
			SELECT
				L.value('@numeroMedidor' , 'VARCHAR(32)') AS NumMedidor
				, L.value('@valor' , 'FLOAT') AS Valor
				, P.ID AS IDPropiedad
			FROM @Xml.nodes('/LecturasMedidor/Lectura') AS T(L)
			INNER JOIN dbo.Propiedad AS P
				ON P.NumMedidor = L.value('@numeroMedidor', 'VARCHAR(32)')
			WHERE L.value('@tipoMovimientoId','INT') = 3
		) L
		INNER JOIN dbo.Propiedad P ON P.ID = L.IDPropiedad;

		COMMIT TRAN;

FinLect:
		IF @outResultCode <> 0
		BEGIN
			SET @tipoEvento = 11;
		END;

		EXEC dbo.InsertarBitacora
			@inIP
			, @inUserName
			, @descripcionEvento
			, @tipoEvento;
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
		BEGIN
			ROLLBACK TRAN;
		END;

		SET @outResultCode = 50008;

		INSERT INTO dbo.DBError(
			UserName
			, Number
			, State
			, Severity
			, Line
			, [Procedure]
			, Message
			, DateTime
		)
		VALUES(
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