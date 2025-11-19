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
			SET @outResultCode = 50002;  -- Validación fallida
			SET @descripcionEvento = 'Error: XML de LecturasMedidor vacío' ;
			GOTO FinLect ;
		END ;

		IF @FechaOperacion IS NULL
		BEGIN
			SET @outResultCode = 50002;  -- Validación fallida
			SET @descripcionEvento = 'Error: Fecha de operación no proporcionada para LecturasMedidor' ;
			GOTO FinLect ;
		END ;

		IF @Xml.exist('/LecturasMedidor/Lectura') = 0
		BEGIN
			SET @outResultCode = 50012;  -- Sin cambios
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
			SET @outResultCode = 50001 ;  -- No encontrado
			SET @descripcionEvento = 'Error: Al menos un medidor de LecturasMedidor no existe en Propiedad' ;
			GOTO FinLect;
		END ;

		DECLARE @MovConsumoTmp TABLE
		(
			Fecha       DATE,
			Monto       FLOAT,
			NuevoSaldo  FLOAT,
			IDTipo      INT,
			IDPropiedad INT
		) ;

		BEGIN TRAN ;

		;WITH LecturasTipo1 AS (
			SELECT
				L.IDPropiedad,
				L.Valor,
				CASE
					WHEN P.UltimaLecturaMedidor IS NULL THEN 0
					WHEN L.Valor - P.UltimaLecturaMedidor < 0 THEN 0
					ELSE L.Valor - P.UltimaLecturaMedidor
				END AS ConsumoDiff
			FROM @Lecturas AS L
			JOIN dbo.Propiedad AS P
				ON P.ID = L.IDPropiedad
			WHERE L.TipoMov = 1
		)
		UPDATE P
		SET  P.UltimaLecturaMedidor = L.Valor ,
			 P.SaldoM3             = P.SaldoM3 + L.ConsumoDiff
		OUTPUT
			@FechaOperacion,
			L.ConsumoDiff,
			inserted.SaldoM3,
			1 ,
			inserted.ID
		INTO @MovConsumoTmp
		(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		FROM dbo.Propiedad AS P
		JOIN LecturasTipo1 AS L
			ON P.ID = L.IDPropiedad;

		;WITH LecturasTipo2 AS (
			SELECT
				L.IDPropiedad,
				CASE
					WHEN L.Valor > P.SaldoM3 THEN P.SaldoM3
					ELSE L.Valor
				END AS ValorAplicado
			FROM @Lecturas AS L
			JOIN dbo.Propiedad AS P
				ON P.ID = L.IDPropiedad
			WHERE L.TipoMov = 2
		)
		UPDATE P
		SET  P.SaldoM3 = P.SaldoM3 - L.ValorAplicado
		OUTPUT
			@FechaOperacion,
			-L.ValorAplicado,
			inserted.SaldoM3,
			2 ,
			inserted.ID
		INTO @MovConsumoTmp
		(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		FROM dbo.Propiedad AS P
		JOIN LecturasTipo2 AS L
			ON P.ID = L.IDPropiedad ;

		;WITH LecturasTipo3 AS (
			SELECT
				L.IDPropiedad,
				L.Valor AS ValorAplicado
			FROM @Lecturas AS L
			WHERE L.TipoMov = 3
		)
		UPDATE P
		SET  P.SaldoM3 = P.SaldoM3 + L.ValorAplicado
		OUTPUT
			@FechaOperacion,
			L.ValorAplicado,
			inserted.SaldoM3,
			3,
			inserted.ID
		INTO @MovConsumoTmp
		(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		FROM dbo.Propiedad AS P
		JOIN LecturasTipo3 AS L
			ON P.ID = L.IDPropiedad ;

		INSERT INTO dbo.MovConsumo
		(
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		)
		SELECT
			Fecha,
			Monto,
			NuevoSaldo,
			IDTipo,
			IDPropiedad
		FROM @MovConsumoTmp;

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

		SET @outResultCode = 50008 ;  -- ErrorBD
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
