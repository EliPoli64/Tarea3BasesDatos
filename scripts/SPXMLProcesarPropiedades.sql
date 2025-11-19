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

        DECLARE @Propiedades TABLE (
            RowID INT IDENTITY(1,1),
            NumFinca VARCHAR(16),
            NumMedidor VARCHAR(32),
            Area DECIMAL(18,2),
            ValorFiscal DECIMAL(18,2),
            TipoUsoID INT,
            TipoAreaID INT,
            FechaReg DATE
        );

        INSERT INTO @Propiedades (
            NumFinca,
            NumMedidor,
            Area,
            ValorFiscal,
            TipoUsoID,
            TipoAreaID,
            FechaReg
        )
        SELECT
            P.value('@numeroFinca', 'VARCHAR(16)'),
            P.value('@numeroMedidor', 'VARCHAR(32)'),
            P.value('@metrosCuadrados', 'DECIMAL(18,2)'),
            P.value('@valorFiscal', 'DECIMAL(18,2)'),
            P.value('@tipoUsoId', 'INT'),
            P.value('@tipoZonaId', 'INT'),
            P.value('@fechaRegistro', 'DATE')
        FROM @Xml.nodes('/Propiedades/Propiedad') AS T(P);

        DECLARE @CurrentRow INT = 1;
        DECLARE @TotalRows INT = (SELECT COUNT(*) FROM @Propiedades);
        DECLARE @CurrentNumFinca VARCHAR(16);
        DECLARE @NumMedidor VARCHAR(32);
        DECLARE @Area DECIMAL(18,2);
        DECLARE @ValorFiscal DECIMAL(18,2);
        DECLARE @TipoUsoID INT;
        DECLARE @TipoAreaID INT;
        DECLARE @FechaReg DATE;

        BEGIN TRANSACTION;

        WHILE @CurrentRow <= @TotalRows
        BEGIN
            SELECT 
                @CurrentNumFinca = NumFinca,
                @NumMedidor = NumMedidor,
                @Area = Area,
                @ValorFiscal = ValorFiscal,
                @TipoUsoID = TipoUsoID,
                @TipoAreaID = TipoAreaID,
                @FechaReg = FechaReg
            FROM @Propiedades 
            WHERE RowID = @CurrentRow;

            IF EXISTS (SELECT 1 FROM dbo.Propiedad WHERE NumFinca = @CurrentNumFinca)
            BEGIN
                SET @outResultCode = 50005;
                SET @descripcionEvento = 'Error: Ya existe una propiedad con la misma finca: ' + @CurrentNumFinca;
                ROLLBACK TRANSACTION;
                GOTO FinPropiedades;
            END;

            INSERT INTO dbo.Propiedad(
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
            VALUES(
                @CurrentNumFinca,
                @Area,
                @ValorFiscal,
                @FechaReg,
                @TipoUsoID,
                @TipoAreaID,
                0,
                0,
                @NumMedidor,
                NULL,
                1
            );

            SET @CurrentRow = @CurrentRow + 1;
        END;

        COMMIT TRANSACTION;

FinPropiedades:
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
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
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