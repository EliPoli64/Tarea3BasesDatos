CREATE OR ALTER PROCEDURE dbo.XMLProcesarPersonas
	@Xml            XML,
	@inUserName     VARCHAR(32),
	@inIP           VARCHAR(32),
	@outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento  VARCHAR(256);
    DECLARE @resultBitacora     INT;
    DECLARE @tipoEvento         INT = 2;
    SET @outResultCode          = 0;
    SET @descripcionEvento      = 'Éxito: Personas procesadas correctamente';

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: XML de Personas está vacío';
            GOTO FinPersonas;
        END;

        IF @Xml.exist('/Personas/Persona') = 0
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Persona> en el XML';
            GOTO FinPersonas;
        END;

        BEGIN TRAN;

        DECLARE @ValorDocumento VARCHAR(32);
        DECLARE @Nombre VARCHAR(64);
        DECLARE @Telefono VARCHAR(16);

        DECLARE personas_cursor CURSOR FOR
        SELECT
            P.value('@valorDocumento', 'VARCHAR(32)') AS ValorDocumento,
            P.value('@nombre', 'VARCHAR(64)') AS Nombre,
            P.value('@telefono', 'VARCHAR(16)') AS Telefono
        FROM @Xml.nodes('/Personas/Persona') AS T(P);

        OPEN personas_cursor;
        FETCH NEXT FROM personas_cursor INTO @ValorDocumento, @Nombre, @Telefono;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Verificar si ya existe el propietario
            IF EXISTS (SELECT 1 FROM dbo.Propietario WHERE ValorDocumentoId = @ValorDocumento)
            BEGIN
                SET @outResultCode = 50005;
                SET @descripcionEvento = 'Error: Ya existe un propietario con el mismo documento: ' + @ValorDocumento;
                CLOSE personas_cursor;
                DEALLOCATE personas_cursor;
                ROLLBACK TRAN;
                GOTO FinPersonas;
            END;

            -- Insertar un propietario a la vez para activar el trigger
            INSERT INTO dbo.Propietario (
                Nombre,
                ValorDocumentoId,
                Telefono,
                EsActivo)
            VALUES(
                @Nombre,
                @ValorDocumento,
                @Telefono,
                1
            );

            FETCH NEXT FROM personas_cursor INTO @ValorDocumento, @Nombre, @Telefono;
        END;

        CLOSE personas_cursor;
        DEALLOCATE personas_cursor;

        COMMIT TRAN;

FinPersonas:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;
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
            ROLLBACK TRAN;
        END;
        SET @outResultCode = 50008;

        INSERT INTO dbo.DBError(
            [UserName],
            [Number],
            [State],
            [Severity],
            [Line],
            [Procedure],
            [Message],
            [DateTime])
        VALUES(
			SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE());
    END CATCH;

    SET NOCOUNT OFF;
END;