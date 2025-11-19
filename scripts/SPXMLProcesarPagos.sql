CREATE OR ALTER PROCEDURE dbo.XMLProcesarPagos
	@Xml                XML
	, @FechaOperacion   DATE
	, @inUserName       VARCHAR(32)
	, @inIP             VARCHAR(32)
	, @outResultCode    INT OUTPUT
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

        BEGIN TRAN;

        WITH PagosActualizados AS (
            SELECT
                F.ID AS IDFactura
                , P.value('@tipoMedioPagoId', 'INT') AS TipoMedioPagoId
                , F.TotalPagarOriginal + 
                    CASE
                        WHEN F.FechaLimitePago < @FechaOperacion
                        THEN CONVERT(MONEY, (F.TotalPagarOriginal * 0.04 / 30.0) * DATEDIFF(DAY, F.FechaLimitePago, @FechaOperacion))
                        ELSE 0
                    END AS TotalPagarFinal
                , CASE
                    WHEN F.FechaLimitePago < @FechaOperacion
                    THEN CONVERT(MONEY, (F.TotalPagarOriginal * 0.04 / 30.0) * DATEDIFF(DAY, F.FechaLimitePago, @FechaOperacion))
                    ELSE 0
                END AS MontoIntereses
                , OC.ID AS OrdenCorteID
                , PR.ID AS IDPropiedad
                , P.value('@numeroReferencia', 'VARCHAR(32)') AS NumeroRef
            FROM @Xml.nodes('/Pagos/Pago') AS T(P)
            INNER JOIN dbo.Propiedad AS PR
                ON PR.NumFinca = P.value('@numeroFinca', 'VARCHAR(16)')
            INNER JOIN (
                SELECT 
                    F.ID
                    , F.FechaLimitePago
                    , F.TotalPagarOriginal
                    , F.IDPropiedad
                    , ROW_NUMBER() OVER (PARTITION BY F.IDPropiedad ORDER BY F.FechaLimitePago ASC) AS RN
                FROM dbo.Factura AS F
                WHERE F.EstadoFactura = 0
            ) F ON F.IDPropiedad = PR.ID AND F.RN = 1
            LEFT JOIN dbo.OrdenCorte AS OC
                ON OC.IDFactura = F.ID AND OC.Estado = 0
        )
        UPDATE F
        SET EstadoFactura = 1
            , IDTipoMedioPago = PA.TipoMedioPagoId
            , TotalPagarFinal = PA.TotalPagarFinal
        FROM dbo.Factura F
        INNER JOIN PagosActualizados PA ON PA.IDFactura = F.ID;

        INSERT INTO dbo.Linea(
            Monto
            , IDFactura
            , IDCC
        )
        SELECT
            PA.MontoIntereses
            , PA.IDFactura
            , 7
        FROM PagosActualizados PA
        WHERE PA.MontoIntereses > 0;

        INSERT INTO dbo.OrdenReconexion(
            ID
            , Fecha
            , IDOrdenCorte
        )
        SELECT
            PA.OrdenCorteID
            , @FechaOperacion
            , PA.OrdenCorteID
        FROM PagosActualizados PA
        WHERE PA.OrdenCorteID IS NOT NULL
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Factura AS F2
                WHERE F2.IDPropiedad = PA.IDPropiedad
                  AND F2.EstadoFactura = 0
                  AND F2.FechaLimitePago < @FechaOperacion
            );

        UPDATE OC
        SET Estado = 1
        FROM dbo.OrdenCorte OC
        INNER JOIN PagosActualizados PA ON PA.OrdenCorteID = OC.ID
        WHERE PA.OrdenCorteID IS NOT NULL
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Factura AS F2
                WHERE F2.IDPropiedad = PA.IDPropiedad
                  AND F2.EstadoFactura = 0
                  AND F2.FechaLimitePago < @FechaOperacion
            );

        INSERT INTO dbo.ComprobantePago(
            Fecha
            , Codigo
            , IDPropiedad
        )
        SELECT
            @FechaOperacion
            , PA.NumeroRef
            , PA.IDPropiedad
        FROM PagosActualizados PA;

        COMMIT TRAN;

FinPagos:
        IF @outResultCode <> 0
        BEGIN
            SET @tipoEvento = 11;
        END;

        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , @descripcionEvento
            , @tipoEvento;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRAN;
        END;

        SET @outResultCode = 50008;

        INSERT INTO dbo.DBError(
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , Message
            , DateTime
        )
        VALUES(
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , GETDATE()
        );
    END CATCH;

    SET NOCOUNT OFF;
END;