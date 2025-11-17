CREATE OR ALTER PROCEDURE dbo.spXML_ProcesarPagos
    @Xml XML,               -- XML con los nodos de Pago(s)
    @FechaOperacion DATE,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT;
    SET @outResultCode = 0;
    SET @tipoEvento = 2;
    SET @descripcionEvento = 'Éxito: Pagos procesados correctamente en fecha ' + CONVERT(VARCHAR(10), @FechaOperacion, 120);

    BEGIN TRY
        IF @Xml IS NULL OR LEN(CAST(@Xml AS NVARCHAR(MAX))) = 0
        BEGIN
            SET @outResultCode = 50090;
            SET @descripcionEvento = 'Error: XML de Pagos vacío';
            GOTO FinPagos;
        END;
        IF @FechaOperacion IS NULL
        BEGIN
            SET @outResultCode = 50091;
            SET @descripcionEvento = 'Error: Fecha de operación no proporcionada para Pagos';
            GOTO FinPagos;
        END;
        BEGIN TRAN;
        DECLARE @NumFinca VARCHAR(16), @TipoPago INT, @Ref VARCHAR(32);
        DECLARE @propID INT, @facturaID INT;
        DECLARE @FechaFactura DATE, @FechaLimite DATE, @FechaCorte DATE;
        DECLARE @TotalOriginal MONEY, @Estado BIT, @TipoMedio INT, @TotalFinal MONEY;
        DECLARE @diasAtraso INT, @montoIntereses MONEY;
        DECLARE @ordenCorteID INT;
        DECLARE curPago CURSOR FOR
        SELECT P.value('@numeroFinca','VARCHAR(16)') as NumFinca,
               P.value('@tipoMedioPagoId','INT') as TipoPago,
               P.value('@numeroReferencia','VARCHAR(32)') as Ref
        FROM @Xml.nodes('/Pagos/Pago') AS T(P);
        OPEN curPago;
        FETCH NEXT FROM curPago INTO @NumFinca, @TipoPago, @Ref;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Validar propiedad
            SELECT @propID = ID FROM dbo.Propiedad WHERE NumFinca = @NumFinca;
            IF @propID IS NULL
            BEGIN
                SET @outResultCode = 50092;
                SET @descripcionEvento = 'Error: Propiedad ' + @NumFinca + ' no existe (Pagos)';
                ROLLBACK TRAN;
                GOTO FinPagos;
            END;
            -- Buscar factura pendiente más antigua de la propiedad
            SELECT TOP 1 
                @facturaID = F.ID,
                @FechaFactura = F.FechaFactura,
                @FechaLimite = F.FechaLimitePago,
                @FechaCorte = F.FechaCorteAgua,
                @TotalOriginal = F.TotalPagarOriginal,
                @Estado = F.EstadoFactura,
                @TipoMedio = F.IDTipoMedioPago,
                @TotalFinal = F.TotalPagarFinal
            FROM dbo.Factura F
            WHERE F.IDPropiedad = @propID AND F.EstadoFactura = 0
            ORDER BY F.FechaLimitePago ASC;
            IF @facturaID IS NULL
            BEGIN
                SET @outResultCode = 50093;
                SET @descripcionEvento = 'Error: No hay factura pendiente para propiedad ' + @NumFinca + ' (Pago no aplicado)';
                ROLLBACK TRAN;
                GOTO FinPagos;
            END;
            -- Calcular interés si vencida
            SET @montoIntereses = 0;
            IF @FechaLimite < @FechaOperacion
            BEGIN
                SET @diasAtraso = DATEDIFF(DAY, @FechaLimite, @FechaOperacion);
                IF @diasAtraso < 0 SET @diasAtraso = 0;  -- sanity check
                -- interés = 4% mensual -> por día = 0.04/30 * dias atraso * total original
                SET @montoIntereses = CONVERT(MONEY, (@TotalOriginal * 0.04/30.0) * @diasAtraso);
            END;
            -- Actualizar factura: marcar pagada, establecer medio de pago y total final
            UPDATE dbo.Factura
            SET EstadoFactura = 1,
                IDTipoMedioPago = @TipoPago,
                TotalPagarFinal = @TotalOriginal + @montoIntereses
            WHERE ID = @facturaID;
            -- Si había intereses, podríamos insertar una línea de detalle de interés (opcional, no requerido explícitamente)
            IF @montoIntereses > 0
            BEGIN
                INSERT INTO dbo.Linea (Monto, IDFactura, IDCC)
                VALUES (@montoIntereses, @facturaID, 7);  -- suponiendo ConceptoCobro 7 = InteresesMoratorios
            END;
            -- Verificar si existe orden de corte asociada a la factura
            SELECT @ordenCorteID = ID FROM dbo.OrdenCorte WHERE IDFactura = @facturaID AND Estado = 0;
            IF @ordenCorteID IS NOT NULL
            BEGIN
                -- Verificar si ya no quedan facturas vencidas para la propiedad
                IF NOT EXISTS(SELECT 1 FROM dbo.Factura 
                              WHERE IDPropiedad = @propID AND EstadoFactura = 0 AND FechaLimitePago < @FechaOperacion)
                BEGIN
                    -- Generar orden de reconexión para la orden de corte
                    INSERT INTO dbo.OrdenReconexion (ID, Fecha, IDOrdenCorte)
                    VALUES (@ordenCorteID, @FechaOperacion, @ordenCorteID);
                    -- Marcar la orden de corte como atendida (Estado = 1, opcional)
                    UPDATE dbo.OrdenCorte SET Estado = 1 WHERE ID = @ordenCorteID;
                END;
            END;
            -- Registrar comprobante de pago
            INSERT INTO dbo.ComprobantePago (Fecha, Codigo, IDPropiedad)
            VALUES (@FechaOperacion, @Ref, @propID);
            FETCH NEXT FROM curPago INTO @NumFinca, @TipoPago, @Ref;
        END;
        CLOSE curPago;
        DEALLOCATE curPago;
        COMMIT TRAN;
FinPagos:
        IF @outResultCode <> 0 
            SET @tipoEvento = 11;
        EXEC dbo.InsertarBitacora 
            @inIP, @inUserName, @descripcionEvento, @tipoEvento,
            @outResultCode = @resultBitacora OUTPUT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SET @outResultCode = 50094;
        INSERT INTO dbo.DBError ([UserName],[Number],[State],[Severity],[Line],[Procedure],[Message],[DateTime])
        VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(),
                ERROR_LINE(), ERROR_PROCEDURE(), ERROR_MESSAGE(), GETDATE());
    END CATCH
    SET NOCOUNT OFF;
END
