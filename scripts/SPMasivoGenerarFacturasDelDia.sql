CREATE OR ALTER PROCEDURE dbo.MasivoGenerarFacturasDelDia
    @inFechaOperacion DATE,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT = 5;
    DECLARE @diasVencimiento INT;
    DECLARE @diasCorteAgua INT;
    
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Exito: Facturas del día generadas - Fecha: ' + CAST(@inFechaOperacion AS VARCHAR);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @diasVencimiento = CAST(Valor AS INT) 
        FROM dbo.ParametrosSistema 
        WHERE Nombre = 'DiasVencimientoFactura';

        SELECT @diasCorteAgua = CAST(Valor AS INT) 
        FROM dbo.ParametrosSistema 
        WHERE Nombre = 'DiasCorteAgua';

        IF @diasVencimiento IS NULL OR @diasCorteAgua IS NULL
        BEGIN
            SET @outResultCode = 50014;
            SET @descripcionEvento = 'Error: Parámetros del sistema no configurados';
        END;

        IF @outResultCode = 0
        BEGIN
            INSERT INTO dbo.Factura (
                FechaFactura, 
                FechaLimitePago, 
                FechaCorteAgua, 
                IDPropiedad, 
                TotalPagarOriginal, 
                EstadoFactura, 
                IDTipoMedioPago, 
                TotalPagarFinal
            )
            SELECT 
                @inFechaOperacion,
                DATEADD(DAY, @diasVencimiento, @inFechaOperacion),
                DATEADD(DAY, @diasCorteAgua, @inFechaOperacion),
                P.ID,
                0,
                0,
                1,
                0
            FROM dbo.Propiedad P
            WHERE (DAY(P.FechaRegistro) = DAY(@inFechaOperacion)
                OR (DAY(P.FechaRegistro) = 31 AND DAY(@inFechaOperacion) IN (28, 29, 30)))
                AND NOT EXISTS (
                    SELECT 1 FROM dbo.Factura F 
                    WHERE F.IDPropiedad = P.ID 
                    AND F.FechaFactura = @inFechaOperacion
                    AND F.EstadoFactura = 0
                );

            UPDATE F
            SET 
                TotalPagarOriginal = (
                    SELECT ISNULL(SUM(
                        CASE 
                            WHEN CC.ID = 1 THEN
                                CASE WHEN (P.SaldoM3 - P.SaldoM3UltimaFactura) > CCA.M3TarifaMinima 
                                    THEN (P.SaldoM3 - P.SaldoM3UltimaFactura) * CCA.CostoM3
                                    ELSE CCA.M3Minimo
                                END
                            WHEN CC.ID = 2 THEN
                                (P.ValorPropiedad * CCTP.Porcentaje) / 12
                            WHEN CC.ID = 3 THEN
                                CASE WHEN P.Area <= 400 THEN 150
                                    ELSE 150 + (CEILING((P.Area - 400) / 200) * 75)
                                END
                            WHEN CC.ID = 4 THEN
                                CCTF.Monto / 6
                            WHEN CC.ID = 7 THEN
                                CCTF.Monto / 12
                            ELSE 0
                        END
                    ), 0)
                    FROM dbo.PropiedadXCC PXC
                    INNER JOIN dbo.ConceptoCobro CC ON PXC.IDCC = CC.ID
                    LEFT JOIN dbo.CCAgua CCA ON CC.ID = CCA.ID
                    LEFT JOIN dbo.CCTarifaPorcentual CCTP ON CC.ID = CCTP.IDTarifa
                    LEFT JOIN dbo.CCTarifaFija CCTF ON CC.ID = CCTF.IDTarifa
                    WHERE PXC.IDPropiedad = F.IDPropiedad
                    AND PXC.Activo = 1
                ),
                TotalPagarFinal = (
                    SELECT ISNULL(SUM(
                        CASE 
                            WHEN CC.ID = 1 THEN
                                CASE WHEN (P.SaldoM3 - P.SaldoM3UltimaFactura) > CCA.M3TarifaMinima 
                                    THEN (P.SaldoM3 - P.SaldoM3UltimaFactura) * CCA.CostoM3
                                    ELSE CCA.M3Minimo
                                END
                            WHEN CC.ID = 2 THEN
                                (P.ValorPropiedad * CCTP.Porcentaje) / 12
                            WHEN CC.ID = 3 THEN
                                CASE WHEN P.Area <= 400 THEN 150
                                    ELSE 150 + (CEILING((P.Area - 400) / 200) * 75)
                                END
                            WHEN CC.ID = 4 THEN
                                CCTF.Monto / 6
                            WHEN CC.ID = 7 THEN
                                CCTF.Monto / 12
                            ELSE 0
                        END
                    ), 0)
                    FROM dbo.PropiedadXCC PXC
                    INNER JOIN dbo.ConceptoCobro CC ON PXC.IDCC = CC.ID
                    LEFT JOIN dbo.CCAgua CCA ON CC.ID = CCA.ID
                    LEFT JOIN dbo.CCTarifaPorcentual CCTP ON CC.ID = CCTP.IDTarifa
                    LEFT JOIN dbo.CCTarifaFija CCTF ON CC.ID = CCTF.IDTarifa
                    WHERE PXC.IDPropiedad = F.IDPropiedad
                    AND PXC.Activo = 1
                )
            FROM dbo.Factura F
            INNER JOIN dbo.Propiedad P ON F.IDPropiedad = P.ID
            WHERE F.FechaFactura = @inFechaOperacion
            AND F.EstadoFactura = 0;

            UPDATE P
            SET SaldoM3UltimaFactura = P.SaldoM3
            FROM dbo.Propiedad P
            INNER JOIN dbo.Factura F ON P.ID = F.IDPropiedad
            WHERE F.FechaFactura = @inFechaOperacion
            AND F.EstadoFactura = 0;
        END;

        IF (@outResultCode != 0)
        BEGIN
            SET @tipoEvento = 11;
            ROLLBACK TRANSACTION;
        END
        ELSE
        BEGIN
            COMMIT TRANSACTION;
        END;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @outResultCode = 50008;
        INSERT INTO dbo.DBError (
            UserName,
            Number,
            State,
            Severity,
            Line,
            [Procedure],
            Message,
            DateTime
        ) VALUES (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE()
        );

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            'Error inesperado al generar facturas del día',
            11,
            @outResultCode = @resultBitacora OUTPUT;
    END CATCH;
    SET NOCOUNT OFF;
END;
GO