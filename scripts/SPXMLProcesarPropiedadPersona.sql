CREATE OR ALTER PROCEDURE dbo.XMLProcesarPropiedadPersona
	@Xml            XML ,
	@FechaOperacion DATE ,
	@inUserName     VARCHAR(32) ,
	@inIP           VARCHAR(32) ,
	@outResultCode  INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON ;

	DECLARE @descripcionEvento VARCHAR(256) ;
	DECLARE @resultBitacora INT ;
	DECLARE @tipoEvento INT = 2 ;
	DECLARE @TotalBajas INT ;
	DECLARE @Actualizadas INT ;

	SET @outResultCode = 0 ;
	SET @descripcionEvento = 'Éxito: Asociaciones Propiedad-Persona procesadas correctamente' ;

	BEGIN TRY
		IF @Xml IS NULL
		   OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
		BEGIN
			SET @outResultCode     = 50002 ;
			SET @descripcionEvento = 'Error: XML de PropiedadPersona vacío' ;
			GOTO FinPropiedadPersona ;
		END ;

		IF @Xml.exist('/PropiedadPersona/Movimiento') = 0
		BEGIN
			SET @outResultCode     = 50012 ;
			SET @descripcionEvento = 'Sin cambios: No hay nodos <PropiedadPersona> en el XML' ;
			GOTO FinPropiedadPersona ;
		END ;

		IF @FechaOperacion IS NULL
		BEGIN
			SET @outResultCode     = 50002 ;
			SET @descripcionEvento = 'Error: Fecha de operación no proporcionada en PropiedadPersona' ;
			GOTO FinPropiedadPersona ;
		END ;

		DECLARE @PropiedadPersonaConIds TABLE
		(
			ValorDoc VARCHAR(32) ,
			NumFinca VARCHAR(16) ,
			TipoAsociacionId INT ,
			IDPropietario INT ,
			IDPropiedad INT
		) ;

		INSERT INTO @PropiedadPersonaConIds
		(
			ValorDoc ,
			NumFinca ,
			TipoAsociacionId ,
			IDPropietario ,
			IDPropiedad
		)
		SELECT
			X.ValorDoc ,
			X.NumFinca ,
			X.TipoAsociacionId ,
			PR.ID AS IDPropietario ,
			PP.ID AS IDPropiedad
		FROM (
				SELECT
					P.value('@valorDocumento' , 'VARCHAR(32)') AS ValorDoc ,
					P.value('@numeroFinca' , 'VARCHAR(16)') AS NumFinca ,
					P.value('@tipoAsociacionId' , 'INT') AS TipoAsociacionId
				FROM @Xml.nodes('/PropiedadPersona/Movimiento') AS T(P)
		     ) AS X
		LEFT JOIN dbo.Propietario AS PR
			ON PR.ValorDocumentoId = X.ValorDoc
		LEFT JOIN dbo.Propiedad  AS PP
			ON PP.NumFinca = X.NumFinca ;

		IF EXISTS (
			SELECT 1
			FROM @PropiedadPersonaConIds
			WHERE IDPropietario IS NULL
		)
		BEGIN
			SET @outResultCode = 50001 ;
			SET @descripcionEvento = 'Error: Al menos un propietario de PropiedadPersona no existe' ;
			GOTO FinPropiedadPersona ;
		END ;

		IF EXISTS (
			SELECT 1
			FROM @PropiedadPersonaConIds
			WHERE IDPropiedad IS NULL
		)
		BEGIN
			SET @outResultCode = 50001 ;
			SET @descripcionEvento = 'Error: Al menos una propiedad de PropiedadPersona no existe' ;
			GOTO FinPropiedadPersona ;
		END ;

		IF EXISTS (
			SELECT 1
			FROM @PropiedadPersonaConIds AS X
			JOIN dbo.AsociacionPxP AS A
				ON  A.IDPropietario = X.IDPropietario
				AND A.IDPropiedad  = X.IDPropiedad
				AND A.FechaFin     = '9999-12-31'
			WHERE X.TipoAsociacionId = 1
		)
		BEGIN
			SET @outResultCode = 50004 ;
			SET @descripcionEvento = 'Error: Existe al menos una asociación Propiedad-Persona ya activa' ;
			GOTO FinPropiedadPersona ;
		END ;

		BEGIN TRAN ;

		DECLARE @ValorDocMov VARCHAR(32);
		DECLARE @NumFincaMov VARCHAR(16);
		DECLARE @TipoAsociacionIdMov INT;
		DECLARE @IDPropietarioMov INT;
		DECLARE @IDPropiedadMov INT;

		DECLARE movimientos_cursor CURSOR FOR
		SELECT ValorDoc, NumFinca, TipoAsociacionId, IDPropietario, IDPropiedad
		FROM @PropiedadPersonaConIds
		WHERE TipoAsociacionId = 1;

		OPEN movimientos_cursor;
		FETCH NEXT FROM movimientos_cursor INTO @ValorDocMov, @NumFincaMov, @TipoAsociacionIdMov, @IDPropietarioMov, @IDPropiedadMov;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT INTO dbo.AsociacionPxP
			(
				FechaInicio ,
				FechaFin ,
				IDPropiedad ,
				IDPropietario ,
				IDTipoAsociacion
			)
			VALUES(
				@FechaOperacion ,
				'9999-12-31' ,
				@IDPropiedadMov ,
				@IDPropietarioMov ,
				1
			);

			FETCH NEXT FROM movimientos_cursor INTO @ValorDocMov, @NumFincaMov, @TipoAsociacionIdMov, @IDPropietarioMov, @IDPropiedadMov;
		END;

		CLOSE movimientos_cursor;
		DEALLOCATE movimientos_cursor;

		SELECT @TotalBajas = COUNT(*)
		FROM @PropiedadPersonaConIds
		WHERE TipoAsociacionId = 2 ;

		IF @TotalBajas > 0
		BEGIN
			DECLARE @ValorDocBaja VARCHAR(32);
			DECLARE @NumFincaBaja VARCHAR(16);
			DECLARE @TipoAsociacionIdBaja INT;
			DECLARE @IDPropietarioBaja INT;
			DECLARE @IDPropiedadBaja INT;

			DECLARE bajas_cursor CURSOR FOR
			SELECT ValorDoc, NumFinca, TipoAsociacionId, IDPropietario, IDPropiedad
			FROM @PropiedadPersonaConIds
			WHERE TipoAsociacionId = 2;

			OPEN bajas_cursor;
			FETCH NEXT FROM bajas_cursor INTO @ValorDocBaja, @NumFincaBaja, @TipoAsociacionIdBaja, @IDPropietarioBaja, @IDPropiedadBaja;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				UPDATE dbo.AsociacionPxP
				SET FechaFin = @FechaOperacion
				WHERE IDPropietario = @IDPropietarioBaja
				  AND IDPropiedad = @IDPropiedadBaja
				  AND FechaFin = '9999-12-31';

				IF @@ROWCOUNT = 0
				BEGIN
					SET @outResultCode = 50004;
					SET @descripcionEvento = 'Error: Una o más asociaciones a desasociar no tienen estado activo';
					CLOSE bajas_cursor;
					DEALLOCATE bajas_cursor;
					ROLLBACK TRAN;
					GOTO FinPropiedadPersona;
				END;

				FETCH NEXT FROM bajas_cursor INTO @ValorDocBaja, @NumFincaBaja, @TipoAsociacionIdBaja, @IDPropietarioBaja, @IDPropiedadBaja;
			END;

			CLOSE bajas_cursor;
			DEALLOCATE bajas_cursor;
		END ;

		COMMIT TRAN ;

FinPropiedadPersona:
		IF @outResultCode <> 0
		BEGIN
			SET @tipoEvento = 11 ;
		END ;

		EXEC dbo.InsertarBitacora
			@inIP ,
			@inUserName ,
			@descripcionEvento ,
			@tipoEvento ;
	END TRY
	BEGIN CATCH
		IF XACT_STATE() <> 0
		BEGIN
			ROLLBACK TRAN ;
		END ;

		SET @outResultCode = 50008 ;

		INSERT INTO dbo.DBError
		(
			[UserName] ,
			[Number] ,
			[State] ,
			[Severity] ,
			[Line] ,
			[Procedure] ,
			[Message] ,
			[DateTime]
		)
		VALUES
		(
			SUSER_SNAME() ,
			ERROR_NUMBER() ,
			ERROR_STATE() ,
			ERROR_SEVERITY() ,
			ERROR_LINE() ,
			ERROR_PROCEDURE() ,
			ERROR_MESSAGE() ,
			GETDATE()
		) ;
	END CATCH ;

	SET NOCOUNT OFF ;
END ;