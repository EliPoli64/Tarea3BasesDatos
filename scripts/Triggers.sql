CREATE OR ALTER TRIGGER dbo.PropiedadDespuesInsert
ON dbo.Propiedad
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BaseID INT;
    SELECT @BaseID = ISNULL(MAX(ID), 0) FROM dbo.PropiedadXCC;
    
    INSERT INTO dbo.PropiedadXCC (
            ID
            , IDPropiedad
            , IDCC
            , FechaAsociacion
            , Activo
        )
    SELECT 
            @BaseID + ROW_NUMBER() OVER (ORDER BY i.ID)
            , i.ID
            , CASE WHEN 1 = 1 THEN 1 END
            , GETDATE()
            , 1
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.PropiedadXCC PXC 
        WHERE PXC.IDPropiedad = i.ID AND PXC.IDCC = 1
    )
    UNION ALL
    SELECT 
            @BaseID + ROW_NUMBER() OVER (ORDER BY i.ID) + (SELECT COUNT(*) FROM inserted)
            , i.ID
            , CASE WHEN 1 = 1 THEN 2 END
            , GETDATE()
            , 1
    FROM inserted i
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.PropiedadXCC PXC 
        WHERE PXC.IDPropiedad = i.ID AND PXC.IDCC = 2
    )
    UNION ALL
    SELECT 
            @BaseID + ROW_NUMBER() OVER (ORDER BY i.ID) + (SELECT COUNT(*) FROM inserted)*2
            , i.ID
            , CASE WHEN i.IDTipoArea != 2 THEN 3 END
            , GETDATE()
            , 1
    FROM inserted i
    WHERE i.IDTipoArea != 2
    AND NOT EXISTS (
        SELECT 1 FROM dbo.PropiedadXCC PXC 
        WHERE PXC.IDPropiedad = i.ID AND PXC.IDCC = 3
    )
    UNION ALL
    SELECT 
            @BaseID + ROW_NUMBER() OVER (ORDER BY i.ID) + (SELECT COUNT(*) FROM inserted)*3
            , i.ID
            , CASE WHEN i.IDTipoArea IN (1, 5) THEN 7 END
            , GETDATE()
            , 1
    FROM inserted i
    WHERE i.IDTipoArea IN (1, 5)
    AND NOT EXISTS (
        SELECT 1 FROM dbo.PropiedadXCC PXC 
        WHERE PXC.IDPropiedad = i.ID AND PXC.IDCC = 7
    );
END;
GO

---

CREATE OR ALTER TRIGGER dbo.PropiedadAntesInsert
ON dbo.Propiedad
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.Propiedad p ON i.NumFinca = p.NumFinca
    )
    BEGIN
        RAISERROR('No se puede insertar propiedad con número de finca duplicado', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.Propiedad (
            ID
            , NumFinca
            , Area
            , ValorPropiedad
            , FechaRegistro
            , IDTipoUso
            , IDTipoArea
            , SaldoM3
            , SaldoM3UltimaFactura
            , NumMedidor
            , UltimaLecturaMedidor
            , EsActivo
        )
    SELECT 
            ID
            , NumFinca
            , Area
            , ValorPropiedad
            , FechaRegistro
            , IDTipoUso
            , IDTipoArea
            , SaldoM3
            , SaldoM3UltimaFactura
            , NumMedidor
            , UltimaLecturaMedidor
            , 1
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.PropietarioAntesInsert
ON dbo.Propietario
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.Propietario p ON i.ValorDocumentoId = p.ValorDocumentoId
    )
    BEGIN
        RAISERROR('No se puede insertar propietario con documento de identidad duplicado', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.Propietario (
            ID
            , Nombre
            , ValorDocumentoId
            , Telefono
            , EsActivo
        )
    SELECT 
            ID
            , Nombre
            , ValorDocumentoId
            , Telefono
            , 1
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.AsociacionPxPAntesInsert
ON dbo.AsociacionPxP
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    UPDATE dbo.AsociacionPxP
    SET FechaFin = DATEADD(DAY, -1, (SELECT FechaInicio FROM inserted))
    WHERE IDPropiedad IN (SELECT IDPropiedad FROM inserted)
        AND IDPropietario IN (SELECT IDPropietario FROM inserted)
        AND FechaFin = '9999-12-31'
        AND IDTipoAsociacion = 1;
    
    INSERT INTO dbo.AsociacionPxP (
            FechaInicio
            , FechaFin
            , IDPropiedad
            , IDPropietario
            , IDTipoAsociacion
        )
    SELECT 
            FechaInicio
            , FechaFin
            , IDPropiedad
            , IDPropietario
            , IDTipoAsociacion
    FROM inserted;
    
    COMMIT TRANSACTION;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.MovConsumoAntesInsert
ON dbo.MovConsumo
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        LEFT JOIN dbo.Propiedad p ON i.IDPropiedad = p.ID 
        WHERE p.ID IS NULL
    )
    BEGIN
        RAISERROR('Una o más propiedades referenciadas no existen', 16, 1);
        RETURN;
    END;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        LEFT JOIN dbo.TipoMovConsumo t ON i.IDTipo = t.ID 
        WHERE t.ID IS NULL
    )
    BEGIN
        RAISERROR('Uno o más tipos de movimiento no existen', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.MovConsumo (
            Fecha
            , Monto
            , NuevoSaldo
            , IDTipo
            , IDPropiedad
        )
    SELECT 
            Fecha
            , Monto
            , NuevoSaldo
            , IDTipo
            , IDPropiedad
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.FacturaAntesInsert
ON dbo.Factura
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.Factura f ON i.IDPropiedad = f.IDPropiedad 
            AND i.FechaFactura = f.FechaFactura
            AND f.EstadoFactura = 0
    )
    BEGIN
        RAISERROR('Ya existe una factura pendiente para esta propiedad en esta fecha', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.Factura (
            FechaFactura
            , FechaLimitePago
            , FechaCorteAgua
            , IDPropiedad
            , TotalPagarOriginal
            , EstadoFactura
            , IDTipoMedioPago
            , TotalPagarFinal
        )
    SELECT 
            FechaFactura
            , FechaLimitePago
            , FechaCorteAgua
            , IDPropiedad
            , TotalPagarOriginal
            , EstadoFactura
            , IDTipoMedioPago
            , TotalPagarFinal
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.ComprobantePagoAntesInsert
ON dbo.ComprobantePago
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        LEFT JOIN dbo.Propiedad p ON i.IDPropiedad = p.ID 
        WHERE p.ID IS NULL
    )
    BEGIN
        RAISERROR('Una o más propiedades referenciadas no existen', 16, 1);
        RETURN;
    END;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.ComprobantePago cp ON i.Codigo = cp.Codigo
    )
    BEGIN
        RAISERROR('Ya existe un comprobante de pago con este código', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.ComprobantePago (
            Fecha
            , Codigo
            , IDPropiedad
        )
    SELECT 
            Fecha
            , Codigo
            , IDPropiedad
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.OrdenCorteAntesInsert
ON dbo.OrdenCorte
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        LEFT JOIN dbo.Factura f ON i.IDFactura = f.ID 
        WHERE f.ID IS NULL
    )
    BEGIN
        RAISERROR('Una o más facturas referenciadas no existen', 16, 1);
        RETURN;
    END;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.OrdenCorte oc ON i.IDFactura = oc.IDFactura 
            AND oc.Estado = 1
    )
    BEGIN
        RAISERROR('Ya existe una orden de corte activa para esta factura', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.OrdenCorte (
            Fecha
            , Estado
            , IDFactura
        )
    SELECT 
            Fecha
            , Estado
            , IDFactura
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.OrdenReconexionAntesInsert
ON dbo.OrdenReconexion
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        LEFT JOIN dbo.OrdenCorte oc ON i.IDOrdenCorte = oc.ID 
        WHERE oc.ID IS NULL
    )
    BEGIN
        RAISERROR('Una o más órdenes de corte referenciadas no existen', 16, 1);
        RETURN;
    END;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.OrdenReconexion orx ON i.IDOrdenCorte = orx.IDOrdenCorte
    )
    BEGIN
        RAISERROR('Ya existe una orden de reconexión para esta orden de corte', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.OrdenReconexion (
            ID
            , Fecha
            , IDOrdenCorte
        )
    SELECT 
            ID
            , Fecha
            , IDOrdenCorte
    FROM inserted;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.MovConsumoDespuesInsertUpdateSaldo
ON dbo.MovConsumo
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE p
    SET p.SaldoM3 = i.NuevoSaldo
    FROM dbo.Propiedad p
    INNER JOIN inserted i ON p.ID = i.IDPropiedad;
END;
GO

---

CREATE OR ALTER TRIGGER dbo.UsuarioAntesInsert
ON dbo.Usuario
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        INNER JOIN dbo.Usuario u ON i.UserName = u.UserName
    )
    BEGIN
        RAISERROR('No se puede insertar usuario con nombre de usuario duplicado', 16, 1);
        RETURN;
    END;
    
    INSERT INTO dbo.Usuario (
            ID
            , UserName
            , Password
            , EsActivo
            , IDTipo
        )
    SELECT 
            ID
            , UserName
            , Password
            , EsActivo
            , IDTipo
    FROM inserted;
END;
GO