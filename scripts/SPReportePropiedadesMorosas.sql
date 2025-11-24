CREATE OR ALTER PROCEDURE dbo.ReportePropiedadesMorosas
    @inUserName VARCHAR(32)
    , @inIP VARCHAR(32)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT 
            p.NumFinca,
            pr.Nombre as Propietario,
            COUNT(f.ID) as FacturasVencidas,
            SUM(f.TotalPagarFinal) as TotalAdeudado,
            MAX(f.FechaLimitePago) as FechaVencimientoMasReciente
        FROM Propiedad p
        INNER JOIN Factura f ON p.ID = f.IDPropiedad
        INNER JOIN AsociacionPxP ap ON p.ID = ap.IDPropiedad
        INNER JOIN Propietario pr ON ap.IDPropietario = pr.ID
        WHERE f.EstadoFactura = 0
        AND f.FechaLimitePago < GETDATE()
        AND ap.FechaFin > GETDATE()
        GROUP BY p.NumFinca, pr.Nombre
        HAVING COUNT(f.ID) > 0
        ORDER BY TotalAdeudado DESC;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Reporte propiedades morosas generado'
            , 2;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008;
        INSERT INTO dbo.DBError (
			[UserName]
			, [Number]
			, [State]
			, [Severity]
			, [Line]
			, [Procedure]
			, [Message]
			, [DateTime]
		) VALUES (
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
END;
GO