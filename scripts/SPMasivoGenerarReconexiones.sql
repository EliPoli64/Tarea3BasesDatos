CREATE OR ALTER PROCEDURE dbo.MasivoGenerarReconexiones
    @inFechaOperacion DATE,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT = 8;
    
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Exito: Reconexiones generadas masivamente - Fecha: ' + CAST(@inFechaOperacion AS VARCHAR);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.OrdenReconexion (
            Fecha,
            IDOrdenCorte
        )
        SELECT 
            @inFechaOperacion,
            OC.ID
        FROM dbo.OrdenCorte OC
        INNER JOIN dbo.Factura F ON OC.IDFactura = F.ID
        WHERE F.EstadoFactura = 1
            AND OC.Estado = 1
            AND NOT EXISTS (
                SELECT 1 FROM dbo.OrdenReconexion ORX 
                WHERE ORX.IDOrdenCorte = OC.ID
            );

        UPDATE OC
        SET Estado = 2
        FROM dbo.OrdenCorte OC
        INNER JOIN dbo.Factura F ON OC.IDFactura = F.ID
        WHERE F.EstadoFactura = 1
            AND OC.Estado = 1;

        IF (@outResultCode != 0)
        BEGIN
            SET @tipoEvento = 11;
            ROLLBACK TRANSACTION;
        END
        ELSE
        BEGIN
            COMMIT TRANSACTION;
        END;

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            @descripcionEvento,
            @tipoEvento;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @outResultCode = 50008;
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

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            'Error inesperado al generar reconexiones masivas',
            11,
            @outResultCode = @resultBitacora OUTPUT;
    END CATCH;
    SET NOCOUNT OFF;
END;
GO