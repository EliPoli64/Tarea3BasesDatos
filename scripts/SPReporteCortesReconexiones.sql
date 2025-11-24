CREATE OR ALTER PROCEDURE dbo.ReporteCortesReconexiones
    @inFechaInicio      DATE
    , @inFechaFin       DATE
    , @inUserName       VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;
    
    BEGIN TRY
        SELECT 
            p.NumFinca
            , oc.Fecha as FechaCorte
            , oc.Estado as EstadoCorte
            , orx.Fecha as FechaReconexion
            , f.TotalPagarFinal
        FROM OrdenCorte oc
        INNER JOIN Factura f ON oc.IDFactura = f.ID
        INNER JOIN Propiedad p ON f.IDPropiedad = p.ID
        LEFT JOIN OrdenReconexion orx ON oc.ID = orx.IDOrdenCorte
        WHERE oc.Fecha BETWEEN @inFechaInicio AND @inFechaFin
        ORDER BY oc.Fecha DESC;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Reporte cortes y reconexiones generado'
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