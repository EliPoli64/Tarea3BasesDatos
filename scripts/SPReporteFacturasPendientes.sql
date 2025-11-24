CREATE OR ALTER PROCEDURE dbo.ReporteFacturasPendientes
    @inFechaInicio DATE
    , @inFechaFin DATE
    , @inUserName VARCHAR(32)
    , @inIP VARCHAR(32)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT 
            f.ID,
            p.NumFinca,
            f.FechaFactura,
            f.FechaLimitePago,
            f.TotalPagarFinal,
            DATEDIFF(DAY, f.FechaLimitePago, GETDATE()) as DiasVencida
        FROM Factura f
        INNER JOIN Propiedad p ON f.IDPropiedad = p.ID
        WHERE f.EstadoFactura = 0
        AND f.FechaFactura BETWEEN @inFechaInicio AND @inFechaFin
        ORDER BY f.FechaLimitePago ASC;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Reporte facturas pendientes generado'
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