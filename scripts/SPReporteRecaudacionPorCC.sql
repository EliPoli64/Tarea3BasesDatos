CREATE OR ALTER PROCEDURE dbo.ReporteRecaudacionPorCC
    @inFechaInicio      DATE
    , @inFechaFin         DATE
    , @inUserName         VARCHAR(32)
    , @inIP               VARCHAR(32)
    , @outResultCode      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT 
            cc.Nombre as ConceptoCobro,
            COUNT(l.ID) as CantidadPagos,
            SUM(l.Monto) as TotalRecaudado
        FROM Linea l
        INNER JOIN ConceptoCobro cc ON l.IDCC = cc.ID
        INNER JOIN Factura f ON l.IDFactura = f.ID
        WHERE f.EstadoFactura = 1
        AND f.FechaFactura BETWEEN @inFechaInicio AND @inFechaFin
        GROUP BY cc.ID, cc.Nombre
        ORDER BY TotalRecaudado DESC;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Reporte recaudación por CC generado'
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