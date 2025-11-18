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
    DECLARE @BaseID INT;
    DECLARE @TotalBajas INT;
    DECLARE @Actualizadas INT;
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Éxito: CCPropiedad procesado correctamente';

    BEGIN TRY
        IF @Xml IS NULL
           OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002;  -- Validación fallida
            SET @descripcionEvento = 'Error: XML de CCPropiedad vacío';
            GOTO FinCCProp;
        END;

        IF @Xml.exist('/CCPropiedad/Movimiento') = 0
        BEGIN
            SET @outResultCode = 50012;  -- Sin cambios
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

        -- Propiedad no encontrada
        IF EXISTS (
            SELECT 1
            FROM @Movimientos
            WHERE IDPropiedad IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;  -- No encontrado
            SET @descripcionEvento = 'Error: Al menos una propiedad de CCPropiedad no existe';
            GOTO FinCCProp;
        END;

        -- ConceptoCobro no encontrado
        IF EXISTS (
            SELECT 1
            FROM @Movimientos AS M
            LEFT JOIN dbo.ConceptoCobro AS CC ON CC.ID = M.IDCC
            WHERE CC.ID IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;  -- No encontrado
            SET @descripcionEvento = 'Error: Al menos un concepto de cobro de CCPropiedad no existe';
            GOTO FinCCProp;
        END;

        IF EXISTS (
            SELECT 1
            FROM @Movimientos AS M
            JOIN dbo.PropiedadXCC AS PX
                ON PX.IDPropiedad = M.IDPropiedad
                AND PX.IDCC = M.IDCC
                AND PX.Activo = 1
            WHERE M.TipoAso = 1
        )
        BEGIN
            SET @outResultCode = 50004;  -- Estado no válido
            SET @descripcionEvento = 'Error: Uno o más conceptos ya estaban activos en la propiedad (CCPropiedad)';
            GOTO FinCCProp;
        END;

        IF EXISTS (
            SELECT 1
            FROM @Movimientos AS M
            LEFT JOIN dbo.PropiedadXCC AS PX
                ON PX.IDPropiedad = M.IDPropiedad
                AND PX.IDCC = M.IDCC
                AND PX.Activo = 1
            WHERE M.TipoAso = 2
              AND PX.ID IS NULL
        )
        BEGIN
            SET @outResultCode = 50004;  -- Estado no válido
            SET @descripcionEvento = 'Error: Uno o más conceptos no estaban activos en la propiedad al desasociar (CCPropiedad)';
            GOTO FinCCProp;
        END;

        BEGIN TRAN;
        SELECT @BaseID = ISNULL(MAX(ID), 0)
        FROM dbo.PropiedadXCC;

        ;WITH Altas AS (
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS RowNum,
                M.IDPropiedad,
                M.IDCC
            FROM @Movimientos AS M
            WHERE M.TipoAso = 1
        )
		
        INSERT INTO dbo.PropiedadXCC(
            ID,
            IDPropiedad,
            IDCC,
            FechaAsociacion,
            Activo
        )
        SELECT
            @BaseID + A.RowNum,
            A.IDPropiedad,
            A.IDCC,
            GETDATE(),
            1
        FROM Altas AS A;

        SELECT @TotalBajas = COUNT(*)
        FROM @Movimientos
        WHERE TipoAso = 2;

        IF @TotalBajas > 0
        BEGIN
            UPDATE PX
            SET  PX.Activo = 0
            FROM dbo.PropiedadXCC AS PX
            JOIN @Movimientos AS M
                ON  PX.IDPropiedad = M.IDPropiedad
                AND PX.IDCC = M.IDCC
            WHERE M.TipoAso = 2
              AND PX.Activo = 1;

            SET @Actualizadas = @@ROWCOUNT;

            IF @Actualizadas < @TotalBajas
            BEGIN
                SET @outResultCode = 50004;  -- Estado no válido
                SET @descripcionEvento = 'Error: Uno o más conceptos no estaban activos en la propiedad al desasociar (CCPropiedad)';
                ROLLBACK TRAN;
                GOTO FinCCProp;
            END;
        END;

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

        SET @outResultCode = 50008;  -- ErrorBD

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
