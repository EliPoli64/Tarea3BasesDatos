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

        -- Obtener parámetros del sistema
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
            GOTO FinFacturas;
        END;

        -- Identificar propiedades que deben generar factura hoy
        -- (según el día de su fecha de registro) y que NO tengan factura pendiente del mismo día
        DECLARE @PropiedadesFacturar TABLE (
            IDPropiedad INT PRIMARY KEY,
            NumFinca VARCHAR(16),
            SaldoM3 FLOAT,
            SaldoM3UltimaFactura FLOAT,
            ValorPropiedad DECIMAL(18,2),
            IDTipoUso INT,
            IDTipoArea INT,
            Area DECIMAL(18,2)
        );

        INSERT INTO @PropiedadesFacturar (
            IDPropiedad, 
            NumFinca, 
            SaldoM3, 
            SaldoM3UltimaFactura, 
            ValorPropiedad, 
            IDTipoUso, 
            IDTipoArea, 
            Area
        )
        SELECT 
            P.ID,
            P.NumFinca,
            P.SaldoM3,
            P.SaldoM3UltimaFactura,
            P.ValorPropiedad,
            P.IDTipoUso,
            P.IDTipoArea,
            P.Area
        FROM dbo.Propiedad P
        WHERE P.EsActivo = 1
          AND (
            -- Mismo día del mes
            DAY(P.FechaRegistro) = DAY(@inFechaOperacion)
            -- Para propiedades registradas el día 31, facturar los días 28, 29, 30
            OR (DAY(P.FechaRegistro) = 31 AND DAY(@inFechaOperacion) IN (28, 29, 30))
          )
          -- VERIFICACIÓN MEJORADA: No crear factura si ya existe una del mismo día (pendiente o pagada)
          AND NOT EXISTS (
            SELECT 1 
            FROM dbo.Factura F 
            WHERE F.IDPropiedad = P.ID 
              AND F.FechaFactura = @inFechaOperacion
          );

        -- Verificar si hay propiedades para facturar
        IF NOT EXISTS (SELECT 1 FROM @PropiedadesFacturar)
        BEGIN
            SET @outResultCode = 50012; -- Sin cambios
            SET @descripcionEvento = 'Sin cambios: No hay propiedades para facturar en la fecha ' + CAST(@inFechaOperacion AS VARCHAR);
            GOTO FinFacturas;
        END;

        -- Crear las facturas base SOLO para propiedades que no tienen factura del día
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
            PF.IDPropiedad,
            0, -- Total temporal
            0, -- Estado pendiente
            1, -- Medio de pago por defecto
            0  -- Total final temporal
        FROM @PropiedadesFacturar PF;

        -- Calcular montos para cada concepto de cobro y crear líneas de factura
        DECLARE @FacturasRecienCreadas TABLE (
            IDFactura INT PRIMARY KEY,
            IDPropiedad INT,
            NumFinca VARCHAR(16),
            SaldoM3 FLOAT,
            SaldoM3UltimaFactura FLOAT,
            ValorPropiedad DECIMAL(18,2),
            IDTipoUso INT,
            IDTipoArea INT,
            Area DECIMAL(18,2)
        );

        INSERT INTO @FacturasRecienCreadas (
            IDFactura, 
            IDPropiedad, 
            NumFinca, 
            SaldoM3, 
            SaldoM3UltimaFactura,
            ValorPropiedad,
            IDTipoUso,
            IDTipoArea,
            Area
        )
        SELECT 
            F.ID,
            F.IDPropiedad,
            PF.NumFinca,
            PF.SaldoM3,
            PF.SaldoM3UltimaFactura,
            PF.ValorPropiedad,
            PF.IDTipoUso,
            PF.IDTipoArea,
            PF.Area
        FROM dbo.Factura F
        INNER JOIN @PropiedadesFacturar PF ON F.IDPropiedad = PF.IDPropiedad
        WHERE F.FechaFactura = @inFechaOperacion
          AND F.EstadoFactura = 0;

        -- Procesar cada concepto de cobro según los requisitos
        DECLARE @LineasFactura TABLE (
            IDFactura INT,
            IDCC INT,
            Monto MONEY
        );

        -- 1. Impuesto sobre la propiedad (SIEMPRE - CC ID 2 según PDF)
        -- Verificar si la propiedad tiene este CC activo
        INSERT INTO @LineasFactura (IDFactura, IDCC, Monto)
        SELECT 
            FRC.IDFactura,
            2, -- Impuesto sobre propiedad
            (FRC.ValorPropiedad * 0.01) / 12 -- 1% anual, dividido en 12 meses
        FROM @FacturasRecienCreadas FRC
        WHERE EXISTS (
            SELECT 1 
            FROM dbo.PropiedadXCC PXC 
            WHERE PXC.IDPropiedad = FRC.IDPropiedad 
              AND PXC.IDCC = 2 
              AND PXC.Activo = 1
        );

        -- 2. Consumo de agua (SOLO para uso residencial, industrial o comercial - CC ID 1)
        INSERT INTO @LineasFactura (IDFactura, IDCC, Monto)
        SELECT 
            FRC.IDFactura,
            1, -- Consumo de agua
            CASE 
                WHEN (FRC.SaldoM3 - FRC.SaldoM3UltimaFactura) <= 30 THEN 5000 -- Tarifa mínima
                ELSE 5000 + ((FRC.SaldoM3 - FRC.SaldoM3UltimaFactura - 30) * 1000) -- + 1000 por cada m3 adicional
            END
        FROM @FacturasRecienCreadas FRC
        INNER JOIN dbo.TipoUsoPropiedad TUP ON FRC.IDTipoUso = TUP.ID
        WHERE TUP.Nombre IN ('habitación', 'comercial', 'industrial') -- Residencial, comercial o industrial
          AND EXISTS (
            SELECT 1 
            FROM dbo.PropiedadXCC PXC 
            WHERE PXC.IDPropiedad = FRC.IDPropiedad 
              AND PXC.IDCC = 1 
              AND PXC.Activo = 1
        );

        -- 3. Recolección de basura (SOLO para áreas NO agrícolas - CC ID 3)
        INSERT INTO @LineasFactura (IDFactura, IDCC, Monto)
        SELECT 
            FRC.IDFactura,
            3, -- Recolección de basura
            CASE 
                WHEN FRC.Area <= 400 THEN 150
                ELSE 150 + (CEILING((FRC.Area - 400) / 200.0) * 75)
            END
        FROM @FacturasRecienCreadas FRC
        INNER JOIN dbo.TipoAreaPropiedad TAP ON FRC.IDTipoArea = TAP.ID
        WHERE TAP.Nombre <> 'agrícola'
          AND EXISTS (
            SELECT 1 
            FROM dbo.PropiedadXCC PXC 
            WHERE PXC.IDPropiedad = FRC.IDPropiedad 
              AND PXC.IDCC = 3 
              AND PXC.Activo = 1
        );

        -- 4. Mantenimiento de parques (SOLO para áreas residenciales o comerciales - CC ID 7)
        INSERT INTO @LineasFactura (IDFactura, IDCC, Monto)
        SELECT 
            FRC.IDFactura,
            7, -- Mantenimiento de parques
            2000 / 12 -- 2000 anual, dividido en 12 meses
        FROM @FacturasRecienCreadas FRC
        INNER JOIN dbo.TipoAreaPropiedad TAP ON FRC.IDTipoArea = TAP.ID
        WHERE TAP.Nombre IN ('residencial', 'comercial')
          AND EXISTS (
            SELECT 1 
            FROM dbo.PropiedadXCC PXC 
            WHERE PXC.IDPropiedad = FRC.IDPropiedad 
              AND PXC.IDCC = 7 
              AND PXC.Activo = 1
        );

        -- 5. Patente comercial (SI aplica - CC ID 4)
        INSERT INTO @LineasFactura (IDFactura, IDCC, Monto)
        SELECT 
            FRC.IDFactura,
            4, -- Patente comercial
            150000 / 6 -- 150,000 semestral, dividido en 6 meses
        FROM @FacturasRecienCreadas FRC
        WHERE EXISTS (
            SELECT 1 
            FROM dbo.PropiedadXCC PXC 
            WHERE PXC.IDPropiedad = FRC.IDPropiedad 
              AND PXC.IDCC = 4 
              AND PXC.Activo = 1
        );

        -- Insertar las líneas en la tabla Linea
        INSERT INTO dbo.Linea (Monto, IDFactura, IDCC)
        SELECT Monto, IDFactura, IDCC
        FROM @LineasFactura;

        -- Actualizar los totales de las facturas
        UPDATE F
        SET 
            TotalPagarOriginal = ISNULL(LF.TotalMonto, 0),
            TotalPagarFinal = ISNULL(LF.TotalMonto, 0)
        FROM dbo.Factura F
        LEFT JOIN (
            SELECT IDFactura, SUM(Monto) AS TotalMonto
            FROM @LineasFactura
            GROUP BY IDFactura
        ) LF ON F.ID = LF.IDFactura
        WHERE F.FechaFactura = @inFechaOperacion
          AND F.EstadoFactura = 0;

        -- Actualizar el saldo de M3 para la próxima facturación SOLO para propiedades con CC de agua
        UPDATE P
        SET SaldoM3UltimaFactura = P.SaldoM3
        FROM dbo.Propiedad P
        INNER JOIN @FacturasRecienCreadas FRC ON P.ID = FRC.IDPropiedad
        WHERE EXISTS (
            SELECT 1 
            FROM dbo.PropiedadXCC PXC 
            WHERE PXC.IDPropiedad = P.ID 
              AND PXC.IDCC = 1 
              AND PXC.Activo = 1
        );

        -- Contar facturas generadas
        DECLARE @cantidadFacturas INT = (SELECT COUNT(*) FROM @FacturasRecienCreadas);
        SET @descripcionEvento = 'Éxito: ' + CAST(@cantidadFacturas AS VARCHAR) + 
                                ' facturas generadas - Fecha: ' + CAST(@inFechaOperacion AS VARCHAR);

FinFacturas:
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
            'MasivoGenerarFacturasDelDia',
            ERROR_MESSAGE(),
            GETDATE()
        );

        SET @descripcionEvento = 'Error inesperado al generar facturas del día: ' + ERROR_MESSAGE();
        SET @tipoEvento = 11;
        
        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;
    END CATCH;
    
    SET NOCOUNT OFF;
END;
GO