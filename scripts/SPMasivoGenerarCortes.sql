CREATE OR ALTER PROCEDURE dbo.MasivoGenerarCortes
    @inFechaOperacion DATE,
    @inUserName VARCHAR(32),
    @inIP VARCHAR(32),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @descripcionEvento VARCHAR(256);
    DECLARE @resultBitacora INT;
    DECLARE @tipoEvento INT = 7;
    
    SET @outResultCode = 0;
    SET @descripcionEvento = 'Exito: Cortes generados masivamente - Fecha: ' + CAST(@inFechaOperacion AS VARCHAR);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.OrdenCorte (Fecha, Estado, IDFactura)
        SELECT 
            @inFechaOperacion,
            1,
            F.ID
        FROM dbo.Factura F
        INNER JOIN dbo.Propiedad P ON F.IDPropiedad = P.ID
        INNER JOIN dbo.PropiedadXCC PXC ON P.ID = PXC.IDPropiedad
        INNER JOIN dbo.ConceptoCobro CC ON PXC.IDCC = CC.ID
        WHERE F.EstadoFactura = 0
            AND F.FechaCorteAgua <= @inFechaOperacion
            AND CC.ID = 1
            AND PXC.Activo = 1
            AND NOT EXISTS (
                SELECT 1 FROM dbo.OrdenCorte OC 
                WHERE OC.IDFactura = F.ID 
                AND OC.Estado = 1
            );

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
            @inIP
            , @inUserName
            , @descripcionEvento
            , @tipoEvento;

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

    END CATCH;
    SET NOCOUNT OFF;
END;
GO