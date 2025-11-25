CREATE OR ALTER PROCEDURE dbo.XMLProcesarPagos
    @Xml XML, 
    @FechaOperacion DATE,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @tipoEvento INT = 2;
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Éxito: Pagos procesados correctamente en fecha ' + CONVERT(VARCHAR(10), @FechaOperacion, 120);

    BEGIN TRY
        IF @Xml IS NULL
            OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: XML de Pagos vacío';
            GOTO FinPagos;
        END;

        IF @FechaOperacion IS NULL
        BEGIN
            SET @outResultCode = 50002;
            SET @descripcionEvento = 'Error: Fecha de operación no proporcionada para Pagos';
            GOTO FinPagos;
        END;

        IF @Xml.exist('/Pagos/Pago') = 0
        BEGIN
            SET @outResultCode = 50012;
            SET @descripcionEvento = 'Sin cambios: No hay nodos <Pago> en Pagos';
            GOTO FinPagos;
        END;

        DECLARE @Pagos TABLE(
            NumFinca VARCHAR(16),
            TipoMedioPagoId INT,
            NumeroRef VARCHAR(32),
            IDPropiedad INT,
            IDFactura INT,
            FechaLimite DATE,
            TotalOriginal MONEY,
            OrdenCorteID INT,
            MontoIntereses MONEY
        );

        INSERT INTO @Pagos(
            NumFinca,
            TipoMedioPagoId,
            NumeroRef,
            IDPropiedad,
            IDFactura,
            FechaLimite,
            TotalOriginal,
            OrdenCorteID,
            MontoIntereses
        )
        SELECT
            X.NumFinca,
            X.TipoMedioPagoId,
            X.NumeroRef,
            PR.ID AS IDPropiedad,
            F.ID AS IDFactura,
            F.FechaLimitePago AS FechaLimite,
            F.TotalPagarOriginal AS TotalOriginal,
            OC.ID AS OrdenCorteID,
            0 AS MontoIntereses
        FROM (
            SELECT
                P.value('@numeroFinca', 'VARCHAR(16)') AS NumFinca,
                P.value('@tipoMedioPagoId', 'INT') AS TipoMedioPagoId,
                P.value('@numeroReferencia', 'VARCHAR(32)') AS NumeroRef
            FROM @Xml.nodes('/Pagos/Pago') AS T(P)
            ) AS X
        LEFT JOIN dbo.Propiedad AS PR
            ON PR.NumFinca = X.NumFinca
        OUTER APPLY (
            SELECT TOP (1)
                F.ID,
                F.FechaLimitePago,
                F.TotalPagarOriginal
            FROM dbo.Factura AS F
            WHERE F.IDPropiedad = PR.ID AND F.EstadoFactura = 0
            ORDER BY F.FechaLimitePago ASC
        ) AS F
        OUTER APPLY (
            SELECT TOP (1)
                OC.ID
            FROM dbo.OrdenCorte AS OC
            WHERE OC.IDFactura = F.ID
            AND OC.Estado = 0
        ) AS OC;
        
        IF EXISTS (
            SELECT 1
            FROM @Pagos
            WHERE IDPropiedad IS NULL
        )
        BEGIN
            SET @outResultCode = 50001;
            SET @descripcionEvento = 'Error: Al menos una propiedad del XML de Pagos no existe';
            GOTO FinPagos;
        END;

        UPDATE P
        SET MontoIntereses =
                CASE
                    WHEN P.FechaLimite < @FechaOperacion
                    THEN CONVERT(
                            MONEY, (P.TotalOriginal * 0.04 / 30.0) * DATEDIFF(DAY, P.FechaLimite, @FechaOperacion)
                        )
                    ELSE 0
                END
        FROM @Pagos AS P;

        BEGIN TRAN;

        UPDATE F
        SET EstadoFactura = 1,
            IDTipoMedioPago = P.TipoMedioPagoId,
            TotalPagarFinal = P.TotalOriginal + P.MontoIntereses
        FROM dbo.Factura AS F
        INNER JOIN @Pagos AS P
            ON F.ID = P.IDFactura;

        INSERT INTO dbo.Linea(
            Monto,
            IDFactura,
            IDCC
        )
        SELECT
            P.MontoIntereses,
            P.IDFactura,
            7
        FROM @Pagos AS P
        WHERE P.MontoIntereses > 0;

        DECLARE @Reconexiones TABLE (
            IDOrdenCorte INT,
            FechaOperacion DATE,
            IDPropiedad INT
        );

        INSERT INTO @Reconexiones (
            IDOrdenCorte,
            FechaOperacion,
            IDPropiedad
        )
        SELECT DISTINCT
            P.OrdenCorteID,
            @FechaOperacion,
            P.IDPropiedad
        FROM @Pagos AS P
        WHERE P.OrdenCorteID IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM dbo.Factura AS F2
            WHERE F2.IDPropiedad = P.IDPropiedad
              AND F2.EstadoFactura = 0
              AND F2.FechaLimitePago < @FechaOperacion
        );

        -- *** MODIFICACIÓN AQUÍ: Se asume que ID es IDENTITY y se omite en el INSERT ***
        INSERT INTO dbo.OrdenReconexion(
            Fecha,
            IDOrdenCorte
        )
        SELECT
            R.FechaOperacion,
            R.IDOrdenCorte
        FROM @Reconexiones AS R;

        UPDATE OC
        SET Estado = 1
        FROM dbo.OrdenCorte AS OC
        INNER JOIN @Reconexiones AS R
            ON OC.ID = R.IDOrdenCorte;

        INSERT INTO dbo.ComprobantePago(
            Fecha,
            Codigo,
            IDPropiedad
        )
        SELECT
            @FechaOperacion,
            P.NumeroRef,
            P.IDPropiedad
        FROM @Pagos AS P;

        COMMIT TRAN;

FinPagos:
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