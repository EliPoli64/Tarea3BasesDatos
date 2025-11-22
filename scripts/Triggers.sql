CREATE OR ALTER TRIGGER dbo.PropiedadAntesInsert
ON dbo.Propiedad
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar duplicados de NumFinca
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            INNER JOIN dbo.Propiedad p ON i.NumFinca = p.NumFinca
        )
        BEGIN
            RAISERROR('No se puede insertar propiedad con número de finca duplicado', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Generar nuevo ID si no viene en el INSERT
        DECLARE @NuevoID INT;
        SELECT @NuevoID = ISNULL(MAX(ID), 0) + 1 FROM dbo.Propiedad;
        
        INSERT INTO dbo.Propiedad (
            ID,
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
            EsActivo
        )
        SELECT 
            @NuevoID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            NumFinca,
            Area,
            ValorPropiedad,
            ISNULL(FechaRegistro, GETDATE()),
            IDTipoUso,
            IDTipoArea,
            ISNULL(SaldoM3, 0),
            ISNULL(SaldoM3UltimaFactura, 0),
            NumMedidor,
            UltimaLecturaMedidor,
            1
        FROM inserted;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.PropiedadDespuesInsert
ON dbo.Propiedad
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Obtener el máximo ID actual de PropiedadXCC
        DECLARE @BaseID INT;
        SELECT @BaseID = ISNULL(MAX(ID), 0) FROM dbo.PropiedadXCC;
        
        -- Asignar CC por defecto basado en reglas de negocio
        INSERT INTO dbo.PropiedadXCC (
            ID,
            IDPropiedad,
            IDCC,
            FechaAsociacion,
            Activo
        )
        -- CC 1: ConsumoAgua (siempre se asigna)
        SELECT 
            @BaseID + ROW_NUMBER() OVER (ORDER BY i.ID),
            i.ID,
            1, -- ConsumoAgua
            GETDATE(),
            1
        FROM inserted i
        
        UNION ALL
        
        -- CC 3: ImpuestoPropiedad (siempre se asigna)
        SELECT 
            @BaseID + (SELECT COUNT(*) FROM inserted) + ROW_NUMBER() OVER (ORDER BY i.ID),
            i.ID,
            3, -- ImpuestoPropiedad
            GETDATE(),
            1
        FROM inserted i
        
        UNION ALL
        
        -- CC 4: RecoleccionBasura (excepto áreas agrícolas - IDTipoArea = 2)
        SELECT 
            @BaseID + (SELECT COUNT(*) FROM inserted)*2 + ROW_NUMBER() OVER (ORDER BY i.ID),
            i.ID,
            4, -- RecoleccionBasura
            GETDATE(),
            1
        FROM inserted i
        WHERE i.IDTipoArea != 2
        
        UNION ALL
        
        -- CC 5: MantenimientoParques (solo áreas residenciales y comerciales - IDTipoArea 1 y 5)
        SELECT 
            @BaseID + (SELECT COUNT(*) FROM inserted)*3 + ROW_NUMBER() OVER (ORDER BY i.ID),
            i.ID,
            5, -- MantenimientoParques
            GETDATE(),
            1
        FROM inserted i
        WHERE i.IDTipoArea IN (1, 5);
        
    END TRY
    BEGIN CATCH
        -- Registrar error pero no fallar la inserción de la propiedad
        INSERT INTO dbo.DBError (
            UserName, Number, State, Severity, Line, [Procedure], Message, DateTime
        ) VALUES (
            SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), 
            ERROR_LINE(), 'PropiedadDespuesInsert', ERROR_MESSAGE(), GETDATE()
        );
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.PropietarioAntesInsert
ON dbo.Propietario
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar duplicados de documento
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            INNER JOIN dbo.Propietario p ON i.ValorDocumentoId = p.ValorDocumentoId
        )
        BEGIN
            RAISERROR('No se puede insertar propietario con documento de identidad duplicado', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Generar nuevo ID si no viene
        DECLARE @NuevoID INT;
        SELECT @NuevoID = ISNULL(MAX(ID), 0) + 1 FROM dbo.Propietario;
        
        INSERT INTO dbo.Propietario (
            ID,
            Nombre,
            ValorDocumentoId,
            Telefono,
            EsActivo
        )
        SELECT 
            @NuevoID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            Nombre,
            ValorDocumentoId,
            Telefono,
            1
        FROM inserted;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.UsuarioAntesInsert
ON dbo.Usuario
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar duplicados de UserName
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            INNER JOIN dbo.Usuario u ON i.UserName = u.UserName
        )
        BEGIN
            RAISERROR('No se puede insertar usuario con nombre de usuario duplicado', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Generar nuevo ID si no viene
        DECLARE @NuevoID INT;
        SELECT @NuevoID = ISNULL(MAX(ID), 0) + 1 FROM dbo.Usuario;
        
        INSERT INTO dbo.Usuario (
            ID,
            UserName,
            Password,
            EsActivo,
            IDTipo
        )
        SELECT 
            @NuevoID + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            UserName,
            Password,
            ISNULL(EsActivo, 1),
            IDTipo
        FROM inserted;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.FacturaAntesInsert
ON dbo.Factura
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar si ya existe factura pendiente para la misma propiedad y mes
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            INNER JOIN dbo.Factura f ON i.IDPropiedad = f.IDPropiedad 
                AND YEAR(i.FechaFactura) = YEAR(f.FechaFactura)
                AND MONTH(i.FechaFactura) = MONTH(f.FechaFactura)
                AND f.EstadoFactura = 0
        )
        BEGIN
            RAISERROR('Ya existe una factura pendiente para esta propiedad en este mes', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Insertar normalmente (Factura.ID es identity)
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
            FechaFactura,
            FechaLimitePago,
            FechaCorteAgua,
            IDPropiedad,
            TotalPagarOriginal,
            ISNULL(EstadoFactura, 0),
            ISNULL(IDTipoMedioPago, 1),
            ISNULL(TotalPagarFinal, TotalPagarOriginal)
        FROM inserted;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.MovConsumoAntesInsert
ON dbo.MovConsumo
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar que las propiedades existen
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            LEFT JOIN dbo.Propiedad p ON i.IDPropiedad = p.ID 
            WHERE p.ID IS NULL
        )
        BEGIN
            RAISERROR('Una o más propiedades referenciadas no existen', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Verificar que los tipos de movimiento existen
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            LEFT JOIN dbo.TipoMovConsumo t ON i.IDTipo = t.ID 
            WHERE t.ID IS NULL
        )
        BEGIN
            RAISERROR('Uno o más tipos de movimiento no existen', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Insertar normalmente (MovConsumo.ID es identity)
        INSERT INTO dbo.MovConsumo (
            Fecha,
            Monto,
            NuevoSaldo,
            IDTipo,
            IDPropiedad
        )
        SELECT 
            ISNULL(Fecha, GETDATE()),
            Monto,
            NuevoSaldo,
            IDTipo,
            IDPropiedad
        FROM inserted;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.ComprobantePagoAntesInsert
ON dbo.ComprobantePago
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar que las propiedades existen
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            LEFT JOIN dbo.Propiedad p ON i.IDPropiedad = p.ID 
            WHERE p.ID IS NULL
        )
        BEGIN
            RAISERROR('Una o más propiedades referenciadas no existen', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Verificar duplicados de código (opcional, si quieres códigos únicos)
        IF EXISTS (
            SELECT 1 
            FROM inserted i 
            INNER JOIN dbo.ComprobantePago cp ON i.Codigo = cp.Codigo
        )
        BEGIN
            RAISERROR('Ya existe un comprobante de pago con este código', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;
        
        -- Insertar normalmente (ComprobantePago.ID es identity)
        INSERT INTO dbo.ComprobantePago (
            Fecha,
            Codigo,
            IDPropiedad
        )
        SELECT 
            ISNULL(Fecha, GETDATE()),
            Codigo,
            IDPropiedad
        FROM inserted;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO