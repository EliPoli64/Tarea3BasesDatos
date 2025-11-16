CREATE OR ALTER PROCEDURE dbo.spXML_ProcesarPropiedadPersona
	@Xml XML,
	@FechaOperacion DATE,
	@inUserName   VARCHAR(32),
	@inIP         VARCHAR(32),
	@outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora    INT;
    DECLARE @tipoEvento        INT = 2;
    DECLARE @BaseID            INT;
    DECLARE @TotalBajas        INT;
    DECLARE @Actualizadas      INT;
    SET @outResultCode     = 0;
    SET @descripcionEvento = 'Éxito: Asociaciones Propiedad-Persona procesadas correctamente';

    BEGIN TRY
        IF @Xml IS NULL OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002; -- Validación fallida
            SET @descripcionEvento = 'Error: XML de PropiedadPersona vacío';
            GOTO FinPropiedadPersona;
        END;

        IF @Xml.exist('/PropiedadPersona/PropiedadPersona') = 0
        BEGIN
            SET @outResultCode = 50012; -- Sin cambios
            SET @descripcionEvento = 'Sin cambios: No hay nodos <PropiedadPersona> en el XML';
            GOTO FinPropiedadPersona;
        END;

        IF @FechaOperacion IS NULL
        BEGIN
            SET @outResultCode = 50002; -- Validación fallida
            SET @descripcionEvento = 'Error: Fecha de operación no proporcionada en PropiedadPersona';
            GOTO FinPropiedadPersona;
        END;

        ;WITH PropiedadPersonaXml AS (
            SELECT
                P.value('@valorDocumento', 'VARCHAR(32)') AS ValorDoc,
                P.value('@numeroFinca', 'VARCHAR(16)') AS NumFinca,
                P.value('@tipoAsociacionId', 'INT') AS TipoAsociacionId
            FROM @Xml.nodes('/PropiedadPersona/PropiedadPersona') AS T(P)
        ),
        PropiedadPersonaConIds AS (
            SELECT
                X.ValorDoc,
                X.NumFinca,
                X.TipoAsociacionId,
                PR.ID AS IDPropietario,
                PP.ID AS IDPropiedad
            FROM PropiedadPersonaXml AS X
            LEFT JOIN dbo.Propietario AS PR ON PR.ValorDocumentoId = X.ValorDoc
            LEFT JOIN dbo.Propiedad AS PP ON PP.NumFinca = X.NumFinca
        )

        -- Propietario no encontrado
        IF EXISTS (
            SELECT 1
            FROM PropiedadPersonaConIds
            WHERE IDPropietario IS NULL
        )
        BEGIN
            SET @outResultCode = 50001; -- No encontrado
            SET @descripcionEvento = 'Error: Al menos un propietario de PropiedadPersona no existe';
            GOTO FinPropiedadPersona;
        END;

        -- Propiedad no encontrada
        IF EXISTS (
            SELECT 1
            FROM PropiedadPersonaConIds
            WHERE IDPropiedad IS NULL
        )
        BEGIN
            SET @outResultCode = 50001; -- No encontrado
            SET @descripcionEvento = 'Error: Al menos una propiedad de PropiedadPersona no existe';
            GOTO FinPropiedadPersona;
        END;

        IF EXISTS (
            SELECT 1
            FROM PropiedadPersonaConIds AS X
            JOIN dbo.AsociacionPxP AS A
                ON  A.IDPropietario = X.IDPropietario
                AND A.IDPropiedad = X.IDPropiedad
                AND A.FechaFin = '9999-12-31'
            WHERE X.TipoAsociacionId = 1
        )
        BEGIN
            SET @outResultCode = 50004; -- Estado no válido
            SET @descripcionEvento = 'Error: Existe al menos una asociación Propiedad-Persona ya activa';
            GOTO FinPropiedadPersona;
        END;

        BEGIN TRAN;
        SELECT @BaseID = ISNULL(MAX(ID), 0)
        FROM dbo.AsociacionPxP;
        ;WITH Altas AS (
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS RowNum,
                X.IDPropietario,
                X.IDPropiedad
            FROM PropiedadPersonaConIds AS X
            WHERE X.TipoAsociacionId = 1
        )
		
        INSERT INTO dbo.AsociacionPxP(
            ID,
            FechaInicio,
            FechaFin,
            IDPropiedad,
            IDPropietario,
            IDTipoAsociacion)
        SELECT
            @BaseID + A.RowNum,
            @FechaOperacion,
            '9999-12-31',
            A.IDPropiedad,
            A.IDPropietario,
            1
        FROM Altas AS A;

        SELECT  @TotalBajas = COUNT(*)
        FROM    PropiedadPersonaConIds
        WHERE   TipoAsociacionId = 2;

        IF @TotalBajas > 0
        BEGIN
            UPDATE A
            SET FechaFin = @FechaOperacion
            FROM dbo.AsociacionPxP AS A
            JOIN PropiedadPersonaConIds AS X ON X.IDPropietario = A.IDPropietario AND X.IDPropiedad = A.IDPropiedad
            WHERE X.TipoAsociacionId = 2
              AND A.FechaFin = '9999-12-31';

            SET @Actualizadas = @@ROWCOUNT;
            IF @Actualizadas < @TotalBajas
            BEGIN
                SET @outResultCode = 50004; -- Estado no válido
                SET @descripcionEvento = 'Error: Una o más asociaciones a desasociar no tienen estado activo';
                ROLLBACK TRAN;
                GOTO FinPropiedadPersona;
            END;
        END;

        COMMIT TRAN;

FinPropiedadPersona:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;
        END;

        EXEC dbo.InsertarBitacora
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento,
            @resultBitacora OUTPUT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRAN;
        END;

        SET @outResultCode = 50008;  -- ErrorBD

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
