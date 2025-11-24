CREATE OR ALTER PROCEDURE dbo.ReporteEstadisticasPagos
    @inMeses            INT = 12
    , @inUserName       VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT 
            YEAR(f.FechaFactura) as Año
            , MONTH(f.FechaFactura) as Mes
            , COUNT(f.ID) as TotalFacturas
            , SUM(f.TotalPagarFinal) as TotalRecaudado
            , AVG(f.TotalPagarFinal) as PromedioFactura
        FROM Factura f
        WHERE f.EstadoFactura = 1
        AND f.FechaFactura >= DATEADD(MONTH, -@inMeses, GETDATE())
        GROUP BY YEAR(f.FechaFactura), MONTH(f.FechaFactura)
        ORDER BY Año DESC, Mes DESC;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Reporte estadísticas pagos generado'
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