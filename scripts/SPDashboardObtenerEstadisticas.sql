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

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
		DECLARE @ErrorState INT = ERROR_STATE();
		DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
		DECLARE @ErrorLine INT = ERROR_LINE();
		DECLARE @ErrorProcedure VARCHAR(32) = ERROR_PROCEDURE();
		DECLARE @ErrorMessage VARCHAR(512) = ERROR_MESSAGE();
		DECLARE @UserName VARCHAR(32) = SUSER_SNAME();
		DECLARE @CurrentDate DATETIME = GETDATE();

		EXEC dbo.InsertarError
			@inSUSER_SNAME      = @UserName,
			@inERROR_NUMBER     = @ErrorNumber,
			@inERROR_STATE      = @ErrorState,
			@inERROR_SEVERITY   = @ErrorSeverity,
			@inERROR_LINE       = @ErrorLine,
			@inERROR_PROCEDURE  = @ErrorProcedure,
			@inERROR_MESSAGE    = @ErrorMessage,
			@inGETDATE          = @CurrentDate;
    END CATCH;
    SET NOCOUNT OFF;
END;