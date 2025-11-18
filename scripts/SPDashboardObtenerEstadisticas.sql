CREATE OR ALTER PROCEDURE dbo.DashboardObtenerEstadisticas
    @inUserName                 VARCHAR(32)
    , @inIP                     VARCHAR(32)
    , @outTotalPropiedades      INT OUTPUT
    , @outFacturasPendientes    INT OUTPUT
    , @outRecaudacionMes        MONEY OUTPUT
    , @outCortesProgramados     INT OUTPUT
    , @outResultCode            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @tipoEvento INT = 2;
    
    SET @outResultCode = 0;
    SET @outTotalPropiedades = 0;
    SET @outFacturasPendientes = 0;
    SET @outRecaudacionMes = 0;
    SET @outCortesProgramados = 0;
    SET @descripcionEvento = 'Exito: Dashboard consultado por ' + @inUserName;

    BEGIN TRY
        SELECT @outTotalPropiedades = COUNT(*) 
        FROM dbo.Propiedad 
        WHERE EsActivo = 1;

        SELECT @outFacturasPendientes = COUNT(*) 
        FROM dbo.Factura 
        WHERE EstadoFactura = 0;

        SELECT @outRecaudacionMes = ISNULL(SUM(TotalPagarFinal), 0)
        FROM dbo.Factura 
        WHERE EstadoFactura = 1 
            AND MONTH(FechaFactura) = MONTH(GETDATE()) 
            AND YEAR(FechaFactura) = YEAR(GETDATE());

        SELECT @outCortesProgramados = COUNT(*) 
        FROM dbo.OrdenCorte 
        WHERE Estado = 1;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;

    END TRY
    BEGIN CATCH
        SET @outResultCode = 50008; -- error bd

        INSERT INTO dbo.DBError (
            [UserName],
            [Number],
            [State],
            [Severity],
            [Line],
            [Procedure],
            [Message],
            [DateTime]
        ) VALUES (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            ERROR_MESSAGE(),
            GETDATE()
        );
    END CATCH;
    SET NOCOUNT OFF;
END;