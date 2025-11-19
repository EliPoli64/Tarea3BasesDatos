CREATE OR ALTER PROCEDURE dbo.XMLProcesarCCPropiedad
	@Xml XML,
	@inUserName VARCHAR(32),
	@inIP VARCHAR(32),
	@outResultCode INT OUTPUT
AS
BEGIN 
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT = 2;
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Éxito: CCPropiedad procesado correctamente';

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: XML de CCPropiedad vacío';
            GOTO FinCCProp;
        END;

        IF @Xml.exist('/CCPropiedad/Movimiento') = 0
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Movimiento> en CCPropiedad';
            GOTO FinCCProp;
        END;

        DECLARE @Movimientos TABLE(
            NumFinca VARCHAR(16),
            IDCC INT,
            TipoAso INT,
            IDPropiedad INT
        );

        INSERT INTO @Movimientos(
            NumFinca,
            IDCC,
            TipoAso,
            IDPropiedad
        )
        SELECT
            M.value('@numeroFinca', 'VARCHAR(16)') AS NumFinca,
            M.value('@idCC', 'INT') AS IDCC,
            M.value('@tipoAsociacionId','INT') AS TipoAso,
            P.ID AS IDPropiedad
        FROM @Xml.nodes('/CCPropiedad/Movimiento') AS T(M)
        LEFT JOIN dbo.Propiedad AS P
            ON P.NumFinca = M.value('@numeroFinca', 'VARCHAR(16)');

        IF EXISTS (
            SELECT 1
            FROM @Movimientos
            WHERE IDPropiedad IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;
            SET @descripcionEvento = 'Error: Al menos una propiedad de CCPropiedad no existe';
            GOTO FinCCProp;
        END;

        IF EXISTS (
            SELECT 1
            FROM @Movimientos AS M
            LEFT JOIN dbo.ConceptoCobro AS CC ON CC.ID = M.IDCC
            WHERE CC.ID IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;
            SET @descripcionEvento = 'Error: Al menos un concepto de cobro de CCPropiedad no existe';
            GOTO FinCCProp;
        END;

        BEGIN TRAN;

        DECLARE @NumFincaAltas VARCHAR(16);
        DECLARE @IDCCAltas INT;
        DECLARE @IDPropiedadAltas INT;
        DECLARE @TipoAsoAltas INT;

        DECLARE movimientos_cursor CURSOR FOR
        SELECT NumFinca, IDCC, TipoAso, IDPropiedad
        FROM @Movimientos;

        OPEN movimientos_cursor;
        FETCH NEXT FROM movimientos_cursor INTO @NumFincaAltas, @IDCCAltas, @TipoAsoAltas, @IDPropiedadAltas;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @TipoAsoAltas = 1
            BEGIN
                -- Verificar si ya existe la asociación activa
                IF EXISTS (
                    SELECT 1
                    FROM dbo.PropiedadXCC
                    WHERE IDPropiedad = @IDPropiedadAltas
                      AND IDCC = @IDCCAltas
                      AND Activo = 1
                )
                BEGIN
                    SET @outResultCode = 50004;
                    SET @descripcionEvento = 'Error: El concepto de cobro ya está activo para esta propiedad';
                    CLOSE movimientos_cursor;
                    DEALLOCATE movimientos_cursor;
                    ROLLBACK TRAN;
                    GOTO FinCCProp;
                END;

                -- Insertar una asociación a la vez
                INSERT INTO dbo.PropiedadXCC(
                    IDPropiedad,
                    IDCC,
                    FechaAsociacion,
                    Activo
                )
                VALUES(
                    @IDPropiedadAltas,
                    @IDCCAltas,
                    GETDATE(),
                    1
                );
            END
            ELSE IF @TipoAsoAltas = 2
            BEGIN
                -- Verificar si existe la asociación activa
                IF NOT EXISTS (
                    SELECT 1
                    FROM dbo.PropiedadXCC
                    WHERE IDPropiedad = @IDPropiedadAltas
                      AND IDCC = @IDCCAltas
                      AND Activo = 1
                )
                BEGIN
                    SET @outResultCode = 50004;
                    SET @descripcionEvento = 'Error: El concepto de cobro no está activo para esta propiedad';
                    CLOSE movimientos_cursor;
                    DEALLOCATE movimientos_cursor;
                    ROLLBACK TRAN;
                    GOTO FinCCProp;
                END;

                -- Actualizar una asociación a la vez
                UPDATE dbo.PropiedadXCC
                SET Activo = 0
                WHERE IDPropiedad = @IDPropiedadAltas
                  AND IDCC = @IDCCAltas
                  AND Activo = 1;
            END

            FETCH NEXT FROM movimientos_cursor INTO @NumFincaAltas, @IDCCAltas, @TipoAsoAltas, @IDPropiedadAltas;
        END;

        CLOSE movimientos_cursor;
        DEALLOCATE movimientos_cursor;

        COMMIT TRAN;

FinCCProp:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;
        END;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento
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
            [DateTime]
        )
        VALUES(
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