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

        BEGIN TRAN;

        DECLARE @NumFinca VARCHAR(16);
        DECLARE @NumMedidor VARCHAR(32);
        DECLARE @Area DECIMAL(18,2);
        DECLARE @ValorFiscal DECIMAL(18,2);
        DECLARE @TipoUsoID INT;
        DECLARE @TipoAreaID INT;
        DECLARE @FechaReg DATE;

        DECLARE propiedades_cursor CURSOR FOR
        SELECT
            P.value('@numeroFinca', 'VARCHAR(16)') AS NumFinca,
            P.value('@numeroMedidor', 'VARCHAR(32)') AS NumMedidor,
            P.value('@metrosCuadrados', 'DECIMAL(18,2)') AS Area,
            P.value('@valorFiscal', 'DECIMAL(18,2)') AS ValorFiscal,
            P.value('@tipoUsoId', 'INT') AS TipoUsoID,
            P.value('@tipoZonaId', 'INT') AS TipoAreaID,
            P.value('@fechaRegistro', 'DATE') AS FechaReg
        FROM @Xml.nodes('/Propiedades/Propiedad') AS T(P);

        OPEN propiedades_cursor;
        FETCH NEXT FROM propiedades_cursor INTO @NumFinca, @NumMedidor, @Area, @ValorFiscal, @TipoUsoID, @TipoAreaID, @FechaReg;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Verificar si ya existe la propiedad
            IF EXISTS (SELECT 1 FROM dbo.Propiedad WHERE NumFinca = @NumFinca)
            BEGIN
                SET @outResultCode = 50005;
                SET @descripcionEvento = 'Error: Ya existe una propiedad con la misma finca: ' + @NumFinca;
                CLOSE propiedades_cursor;
                DEALLOCATE propiedades_cursor;
                ROLLBACK TRAN;
                GOTO FinPropiedades;
            END;

            -- Insertar una propiedad a la vez para activar el trigger
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
                @NumFinca,
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

            FETCH NEXT FROM propiedades_cursor INTO @NumFinca, @NumMedidor, @Area, @ValorFiscal, @TipoUsoID, @TipoAreaID, @FechaReg;
        END;

        CLOSE propiedades_cursor;
        DEALLOCATE propiedades_cursor;

        COMMIT TRAN;

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