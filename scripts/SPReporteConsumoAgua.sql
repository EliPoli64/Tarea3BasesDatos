CREATE OR ALTER PROCEDURE dbo.ReporteConsumoAgua
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
            , p.NumMedidor
            , SUM(CASE WHEN mc.IDTipo = 1 THEN mc.Monto ELSE 0 END) as ConsumoM3
            , SUM(CASE WHEN mc.IDTipo = 2 THEN mc.Monto ELSE 0 END) as AjustesCreditoM3
            , SUM(CASE WHEN mc.IDTipo = 3 THEN mc.Monto ELSE 0 END) as AjustesDebitoM3
            , p.SaldoM3 as SaldoActual
        FROM Propiedad p
        LEFT JOIN MovConsumo mc ON p.ID = mc.IDPropiedad
        WHERE mc.Fecha BETWEEN @inFechaInicio AND @inFechaFin
        OR mc.Fecha IS NULL
        GROUP BY p.NumFinca, p.NumMedidor, p.SaldoM3
        ORDER BY ConsumoM3 DESC;
        
        EXEC dbo.InsertarBitacora 
            @inIP
            , @inUserName
            , 'Reporte consumo agua generado'
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