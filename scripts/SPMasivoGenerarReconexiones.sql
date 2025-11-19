CREATE OR ALTER PROCEDURE dbo.MasivoGenerarReconexiones
    @inFechaOperacion   DATE
    , @inUserName       VARCHAR(32)
    , @inIP             VARCHAR(32)
    , @outResultCode    INT OUTPUT
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
            @inIP
            , @inUserName
            , @descripcionEvento
            , @tipoEvento;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @outResultCode = 50008;
        INSERT INTO dbo.DBError (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , Message
            , DateTime
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

        EXEC dbo.InsertarBitacora 
            @inIP,
            @inUserName,
            'Error inesperado al generar reconexiones masivas',
            11;
    END CATCH;
    SET NOCOUNT OFF;
END;
GO