CREATE OR ALTER PROCEDURE dbo.XMLProcesarPropiedades
	@Xml            XML,
	@inUserName     VARCHAR(32),
	@inIP           VARCHAR(32),
	@outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento  VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT = 2;
    DECLARE @BaseID INT;
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Éxito: Propiedades procesadas correctamente';

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: XML de Propiedades está vacío';
            GOTO FinPropiedades;
        END;

        IF @Xml.exist('/Propiedades/Propiedad') = 0
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Propiedad> en el XML';
            GOTO FinPropiedades;
        END;

        IF EXISTS (
            SELECT 1
            FROM @Xml.nodes('/Propiedades/Propiedad') AS T(P)
            JOIN dbo.Propiedad AS PR ON PR.NumFinca = P.value('@numeroFinca', 'VARCHAR(16)')
        )
        BEGIN
            SET @outResultCode = 50005; -- ID duplicada
            SET @descripcionEvento = 'Error: Ya existe al menos una propiedad con la misma finca';
            GOTO FinPropiedades;
        END;

        BEGIN TRAN;
        SELECT @BaseID = ISNULL(MAX(ID), 0)
        FROM dbo.Propiedad;
        WITH PropiedadesXml AS (
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS RowNum,
                P.value('@numeroFinca', 'VARCHAR(16)')  AS NumFinca,
                P.value('@numeroMedidor', 'VARCHAR(32)')  AS NumMedidor,
                P.value('@metrosCuadrados', 'DECIMAL(18,2)') AS Area,
                P.value('@valorFiscal', 'DECIMAL(18,2)') AS ValorFiscal,
                P.value('@tipoUsoId', 'INT') AS TipoUsoID,
                P.value('@tipoZonaId', 'INT') AS TipoAreaID,
                P.value('@fechaRegistro', 'DATE') AS FechaReg
            FROM @Xml.nodes('/Propiedades/Propiedad') AS T(P)
        )

        INSERT INTO dbo.Propiedad(
            ID,
            NumFinca,
            Area,
            ValorPropiedad,
            FechaRegistro,
            IDTipoUso,
            IDTipoArea,
            SaldoM3,
            SaldoM3UltimaFactura,
            NumMedidor,
            UltimaLecturaMedidor,
            EsActivo)
        SELECT
            @BaseID + PX.RowNum,
            PX.NumFinca,
            PX.Area,
            PX.ValorFiscal,
            PX.FechaReg,
            PX.TipoUsoID,
            PX.TipoAreaID,
            0,
            0,
            PX.NumMedidor,
            NULL,
            1
        FROM PropiedadesXml AS PX;
        COMMIT TRAN;

FinPropiedades:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;  -- error
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
        VALUES (
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
